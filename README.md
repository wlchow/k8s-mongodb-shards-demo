# k8s-mongodb-shards-demo

### NOTE
Credit goes to Paul Done. This is a modified version of Paul Done's [MongoDB Sharded Cluster Deployment
Demo for Kubernetes on GKE](https://github.com/pkdone/gke-mongodb-shards-demo)

###  Deployment

Using a command-line terminal/shell, execute the following (first change the password variable in the script "generate.sh", if appropriate):

    $ cd scripts
    $ ./generate.sh

This takes a few minutes to complete. Once completed, you should have a MongoDB Sharded Cluster initialised, secured and running in some Kubernetes StatefulSets. The executed bash script will have created the following resources:

* 1x Config Server Replica Set containing 1x replicas (k8s deployment type: "StatefulSet")
* 2x Shards with 1 Shard being a Replica Set containing 3x replicas and the other Shard being a Replica Set containing 1x replicas (k8s deployment type: "StatefulSet")
* 1x Mongos Routers (k8s deployment type: "StatefulSet")

You can view the list of Pods that contain these MongoDB resources, by running the following:

    $ kubectl get pods

The running mongos router will be accessible to any "app tier" containers, that are running in the same Kubernetes cluster, via the following hostnames and ports (remember to also specify the username and password, when connecting to the database):

    mongos-router-0.mongos-router-service.default.svc.cluster.local:27017

###  Test Sharding Your Own Collection

To test that the sharded cluster is working properly, connect to the container running the first "mongos" router, then use the Mongo Shell to authenticate, enable sharding on a specific collection, add some test data to this collection and then view the status of the Sharded cluster and collection:

    $ kubectl exec -it mongos-router-0 -c mongos-container bash
    $ mongo
    > db.getSiblingDB('admin').auth("main_admin", "abc123");
    > sh.enableSharding("test");
    > use test;
    > db.testcoll.createIndex( { "myfield": 1});
    > sh.shardCollection("test.testcoll", {"myfield": 1});
    > db.testcoll.insert({"myfield": "a", "otherfield": "b"});
    > db.testcoll.find();
    > sh.status();

### Undeploying & Cleaning Down the Kubernetes Environment

Run the following script to undeploy the MongoDB Services & StatefulSets plus related Kubernetes resources.

    $ ./teardown.sh
