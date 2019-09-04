#!/bin/sh
##
# Script to deploy a Kubernetes project with a StatefulSet running a MongoDB
# Sharded Cluster to an existing k8s cluster
##

NEW_PASSWORD="abc123"

# Create keyfile for the MongoDB cluster as a Kubernetes shared secret
TMPFILE=$(mktemp)
/usr/bin/openssl rand -base64 741 > $TMPFILE
kubectl create secret generic shared-bootstrap-data --from-file=internal-auth-mongodb-keyfile=$TMPFILE
rm $TMPFILE

# Deploy a MongoDB ConfigDB Service ("Config Server Replica Set") using a Kubernetes StatefulSet
echo "Deploying k8s StatefulSet & Service for MongoDB Config Server Replica Set"
kubectl apply -f ../resources/mongodb-configdb-service-unsecure.yaml


# Deploy each MongoDB Shard Service using a Kubernetes StatefulSet
echo "Deploying k8s StatefulSet & Service for each MongoDB Shard Replica Set"
kubectl apply -f ../resources/mongodb-maindb-shard1-service-unsecure.yaml
kubectl apply -f ../resources/mongodb-maindb-shard2-service-unsecure.yaml


# Wait until the final mongod of each Shard + the ConfigDB has started properly
echo
echo "Waiting for all the shards and configdb containers to come up (`date`)..."
echo " (IGNORE any reported not found & connection errors)"
sleep 30
echo -n "  "
until kubectl --v=0 exec mongod-configdb-0 -c mongod-configdb-container -- mongo --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done
echo -n "  "
until kubectl --v=0 exec mongod-shard1-2 -c mongod-shard1-container -- mongo --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done
echo -n "  "
until kubectl --v=0 exec mongod-shard2-0 -c mongod-shard2-container -- mongo --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done
echo "...shards & configdb containers are now running (`date`)"
echo


# Initialise the Config Server Replica Set and each Shard Replica Set
echo "Configuring Config Server's & each Shard's Replica Sets"
kubectl exec mongod-configdb-0 -c mongod-configdb-container -- mongo --eval 'rs.initiate({_id: "ConfigDBRepSet", version: 1, members: [ {_id: 0, host: "mongod-configdb-0.mongodb-configdb-service.default.svc.cluster.local:27017"} ]});'
kubectl exec mongod-shard1-0 -c mongod-shard1-container -- mongo --eval 'rs.initiate({_id: "Shard1RepSet", version: 1, members: [ {_id: 0, host: "mongod-shard1-0.mongodb-shard1-service.default.svc.cluster.local:27017"}, {_id: 1, host: "mongod-shard1-1.mongodb-shard1-service.default.svc.cluster.local:27017"}, {_id: 2, host: "mongod-shard1-2.mongodb-shard1-service.default.svc.cluster.local:27017"} ]});'
kubectl exec mongod-shard2-0 -c mongod-shard2-container -- mongo --eval 'rs.initiate({_id: "Shard2RepSet", version: 1, members: [ {_id: 0, host: "mongod-shard2-0.mongodb-shard2-service.default.svc.cluster.local:27017"} ]});'
echo


# Wait for each MongoDB Shard's Replica Set + the ConfigDB Replica Set to each have a primary ready
echo "Waiting for all the MongoDB ConfigDB & Shards Replica Sets to initialise..."
kubectl exec mongod-configdb-0 -c mongod-configdb-container -- mongo --quiet --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
kubectl exec mongod-shard1-0 -c mongod-shard1-container -- mongo --quiet --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
kubectl exec mongod-shard2-0 -c mongod-shard2-container -- mongo --quiet --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
sleep 2 # Just a little more sleep to ensure everything is ready!
echo "...initialisation of the MongoDB Replica Sets completed"
echo

# NOTE: The Mongos should be deployed AFTER the ConfigDBRepSet has been initialized otherwise it will error out with Unable to reach primary for set ConfigDBRepSet
# Deploy some Mongos Routers using a Kubernetes StatefulSet
echo "Deploying k8s Deployment & Service for some Mongos Routers"
kubectl apply -f ../resources/mongodb-mongos-service-unsecure.yaml

# Wait for the mongos to have started properly
echo "Waiting for the first mongos to come up (`date`)..."
echo " (IGNORE any reported not found & connection errors)"
echo -n "  "
until kubectl --v=0 exec mongos-router-0 -c mongos-container -- mongo --quiet --eval 'db.getMongo()'; do
    sleep 2
    echo -n "  "
done
echo "...first mongos is now running (`date`)"
echo


# Add Shards to the Configdb
echo "Configuring ConfigDB to be aware of the 2 Shards"
kubectl exec mongos-router-0 -c mongos-container -- mongo --eval 'sh.addShard("Shard1RepSet/mongod-shard1-0.mongodb-shard1-service.default.svc.cluster.local:27017");'
kubectl exec mongos-router-0 -c mongos-container -- mongo --eval 'sh.addShard("Shard2RepSet/mongod-shard2-0.mongodb-shard2-service.default.svc.cluster.local:27017");'
sleep 3


# Create the Admin User (this will automatically disable the localhost exception)
echo "Creating user: 'main_admin'"
kubectl exec mongos-router-0 -c mongos-container -- mongo --eval 'db.getSiblingDB("admin").createUser({user:"main_admin",pwd:"'"${NEW_PASSWORD}"'",roles:[{role:"root",db:"admin"}]});'
echo


# Print Summary State
kubectl get persistentvolumes
echo
kubectl get all
echo
