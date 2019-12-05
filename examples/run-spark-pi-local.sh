#!/bin/bash

# DO NOT RUN THIS ON A PRODUCTION SYSTEM
# For example use docker.app or minikube with a clean local k8s server
# This script adds helm, the spark-operator, runs spark-pi, displays the status, then tears down spark-operator and helm

# Note that if you use a spark_namespace other than default you need to modify spark-pi.yaml to match
spark_namespace=spark
spark_namespace=default

echo The challenge below is to eliminate all of the sleep invocations and
echo make this script run to completion.

# === In minikube or local docker.app:  (The only real difference is not enabling the web hook and adding/removing helm?
set -x

helm init && sleep 30

if [ "$spark_namespace" != "default" ] ; then
    kubectl create ns  "$spark_namespace" && sleep 5
fi

helm install incubator/sparkoperator --name spark-test --namespace spark-operator --set sparkJobNamespace=$spark_namespace --set enableMetrics=false \
    && sleep 10

kubectl apply --validate=true -f spark-pi.yaml \
    && sleep 10

{
echo 'The key question of this example is how to wait reliably for spark-pi to start and finish then know whether it worked.'
echo 'Note that logs -f knows how to wait until completion...'
echo 'Note also that there is a race condition that this logs command will fail if the job has not started'
} 2> /dev/null

kubectl logs -f -n $spark_namespace spark-pi-driver

exitCode=$(kubectl get -n $spark_namespace pod/spark-pi-driver -o=jsonpath='{.status.containerStatuses[*].state.terminated.exitCode}')
{
  echo exitCode is $exitCode
} 2> /dev/null

# kubectl get -n $spark_namespace sparkapplications spark-pi -o yaml

kubectl get -n $spark_namespace sparkapplications spark-pi -o jsonpath='{"ApplicationState:"}{.status.applicationState.state}{"\nExecutorState:"}{.status.executorState.*}{"\n"}'

statusCode=$(kubectl get -n $spark_namespace sparkapplications spark-pi -o jsonpath='{.status.applicationState.state}')
{
echo statusCode is $statusCode
echo 'Does a statusCode of COMPLETED imply success in the same way that an exitCode of 0 does?'
echo 'Why is the statusCode for the executors FAILED?'
echo "Shouldn't the spark.stop() call cause the executor to exit cleanly?"
} 2> /dev/null

helm list

kubectl delete sparkapplication -n $spark_namespace spark-pi && sleep 15

helm list

{
echo 'Note that helm delete of spark-test does not remove the spark-operator namespace so it is not idempotent.'
echo 'This is understandable since the namespace might have pre-existed and might be used elsewhere.'
} 2> /dev/null
helm delete --purge spark-test && sleep 15

helm list

if [ "$spark_namespace" != "default" ] ; then
    kubectl delete ns  "$spark_namespace" && sleep 10
fi

helm reset && sleep 20


kubectl delete ns spark-operator && sleep 10

exit 0
