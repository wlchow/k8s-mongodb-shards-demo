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
kubectl delete daemonset hostvm-configurer
sleep 3

# Delete persistent volume claims
kubectl delete persistentvolumeclaims -l role=mongodb-shard1
kubectl delete persistentvolumeclaims -l role=mongodb-shard2
kubectl delete persistentvolumeclaims -l role=mongodb-shard3
kubectl delete persistentvolumeclaims -l role=mongo-configdb
sleep 3

# Delete persistent volumes
for i in 1 2 3
do
    kubectl delete persistentvolumes data-volume-4g-$i
done
for i in 1 2 3 4 5 6 7 8 9
do
    kubectl delete persistentvolumes data-volume-8g-$i
done
sleep 20

# Delete GCE disks
for i in 1 2 3
do
    gcloud -q compute disks delete pd-ssd-disk-4g-$i
done
for i in 1 2 3 4 5 6 7 8 9
do
    gcloud -q compute disks delete pd-ssd-disk-8g-$i
done

# Delete whole Kubernetes cluster (including its VM instances)
gcloud -q container clusters delete "gke-mongodb-demo-cluster"


