# chainer-operator

This can introduce `ChainerJob` cutom resource definition into your Kubernetes cluster.

# How to

1. install [metacontroller](https://github.com/GoogleCloudPlatform/metacontroller)

2. install `chainer-operator`
   ```
   $ kubectl -f chainer-operator.yaml

   $ kubectl get crd
   $ k get crd
    NAME                                         AGE
    chainerjobs.k8s.chainer.org                  14h
    compositecontrollers.metacontroller.k8s.io   7d
    controllerrevisions.metacontroller.k8s.io    7d
    decoratorcontrollers.metacontroller.k8s.io   7d
   ```

3. create sshkey secret
   ```
   $ kubectl create -f example/example-ssh-key.yaml
   ```

4. run your first job
   ```
   $ kubectl create -f example/example-chainerjob.yaml
   $ kubectl logs -f example-chainerjob -c chainer
   // you will see chainermn mnist example log (cpu mode.)
   ```
