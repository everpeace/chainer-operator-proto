# chainer-operator

This can introduce `ChainerJob` cutom resource definition into your Kubernetes cluster.

# How to Use

## Administration Task
You firstly install `chainer-operator` to your kubernetes cluster which provides `ChainerJob` custom resource definition(CRD).

`chainer-operator` was implemented as composite controller which is provided [metacontroller](https://github.com/GoogleCloudPlatform/metacontroller).


1. install [metacontroller](https://github.com/GoogleCloudPlatform/metacontroller)

2. install `chainer-operator`
   ```
   # install chainerjob operator scripts(jsonnnet)
   $ kubectl -n metacontroller create configmap chainer-operator-v1alpha1-hooks --from-file=v1alpha1-hooks

   # create 'ChainerJob' CRD and deploy chainerjob operator
   $ kubectl apply -f chainer-operator.yaml

   $ kubectl get crd
   $ k get crd
    NAME                                         AGE
    chainerjobs.kubeflow.org                    14s
    compositecontrollers.metacontroller.k8s.io   1m
    controllerrevisions.metacontroller.k8s.io    1m
    decoratorcontrollers.metacontroller.k8s.io   1m
    ```

## Run your Chainer Jobs
### Case 1: Chainer Job (single pod)
1. (optional) build your image
   ```
   $ cd examples/chainer
   $ ./build-and-publish.sh YOUR_IMAGE_REPO YOUR_IMAGE_TAG
   ```

2. run example job
   ```
   $ cd examples/chainer

   # replace image info in examplejob-chainer.yaml if you built your image

   $ kubectl create -f examplejob-chainer.yaml

   # you can describe chainerjobs
   # you'll see examplejob-chainermn is active.
   $ k describe chainerjobs

   # you can access logs
   # if you're not faimilier with stern??  please visit https://github.com/wercker/stern
   $ stern examplejob-chainer
   // you will see Chainer mnist example log (cpu mode.)

   # when job finished, you can see the job is completed
   $ k describe chainerjobs   
   ```


### Case 2: ChainerMN Job (Multiple Nodes)
1. (optional) build your image
   ```
   $ cd examples/chainermn
   $ ./build-and-publish.sh YOUR_IMAGE_REPO YOUR_IMAGE_TAG
   ```

2. run example job
   ```
   $ cd examples/chainermn

   # replace image info in examplejob-chainermn.yaml if you built your image

   $ kubectl create -f examplejob-chainermn.yaml

   # you can describe chainerjobs
   # you'll see examplejob-chainermn is active.
   $ k describe chainerjobs

   # you can access logs
   # if you're not faimilier with stern??  please visit https://github.com/wercker/stern
   $ stern examplejob-chainermn
   // you will see ChainerMN mnist example log (cpu mode.)

   # when job finished, you can see the job is completed
   $ k describe chainerjobs   
   ```
