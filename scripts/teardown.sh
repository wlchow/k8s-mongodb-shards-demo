#!/bin/sh
##
# Script to remove/undepoy all project resources from k8s
##

# Delete mongos stateful set + mongod stateful set + mongodb service + secrets + host vm configurer daemonset
kubectl delete statefulsets mongosqld-bi
kubectl delete statefulsets mongos-router
kubectl delete services mongos-router-service
kubectl delete statefulsets mongod-shard1
kubectl delete services mongodb-shard1-service
kubectl delete statefulsets mongod-shard2
kubectl delete services mongodb-shard2-service
kubectl delete statefulsets mongod-shard3
kubectl delete services mongodb-shard3-service
kubectl delete statefulsets mongod-configdb
kubectl delete services mongodb-configdb-service
kubectl delete services mongosqld-bi-service
kubectl delete services mongosqld-bi-service-external
kubectl delete secret shared-bootstrap-data
kubectl delete secret mongodb-keyfile
sleep 3

# Delete persistent volume claims
kubectl delete persistentvolumeclaims -l role=mongodb-shard1
kubectl delete persistentvolumeclaims -l role=mongodb-shard2
kubectl delete persistentvolumeclaims -l role=mongodb-shard3
kubectl delete persistentvolumeclaims -l role=mongo-configdb
sleep 3

# Delete persistent volume claims
kubectl delete pv --all


