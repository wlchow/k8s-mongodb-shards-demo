#!/bin/sh
##
# Script to add 3rd Shard with Encryption at Rest Enabled to an existing 2 shard cluster
##

echo "Create an encryption keyfile for the MongoDB cluster as a Kubernetes shared secret"
TMPFILE=$(mktemp)
/usr/bin/openssl rand -base64 32 > $TMPFILE
kubectl create secret generic mongodb-keyfile --from-file=mongodb-encryption-keyfile=$TMPFILE
rm $TMPFILE
kubectl describe secrets/mongodb-keyfile

echo "Deploying k8s StatefulSet & Service for 3rd Shard Replica Set"
kubectl apply -f ../resources/mongodb-maindb-shard3-service-encrypt-only.yaml

echo
echo "Waiting for shard 3 to come up (`date`)..."
until kubectl --v=0 exec mongod-shard3-0 -c mongod-shard3-container -- mongo --quiet --eval 'db.getMongo()'; do
    sleep 5
    echo -n "  "
done
echo "...shard 3 is now running (`date`)"
echo

echo "Initialise the Shard 3 Replica Set"
kubectl exec mongod-shard3-0 -c mongod-shard3-container -- mongo --eval 'rs.initiate({_id: "Shard3RepSet", version: 1, members: [ {_id: 0, host: "mongod-shard3-0.mongodb-shard3-service.default.svc.cluster.local:27017"} ]});'
echo

echo "Waiting for Shard 3 Replica Sets to initialise..."
kubectl exec mongod-shard3-0 -c mongod-shard3-container -- mongo --quiet --eval 'while (rs.status().hasOwnProperty("myState") && rs.status().myState != 1) { print("."); sleep(1000); };'
sleep 2 # Just a little more sleep to ensure everything is ready!
echo "...initialisation of the MongoDB Replica Sets completed"
echo

# Add Shards to the Configdb
echo "Configuring ConfigDB to be aware of Shard 3"
kubectl exec mongos-router-0 -c mongos-container -- mongo --eval 'sh.addShard("Shard3RepSet/mongod-shard3-0.mongodb-shard3-service.default.svc.cluster.local:27017");'
sleep 3


# Print Summary State
kubectl get persistentvolumes
echo
kubectl get all
echo
