# HOW TO INSTALL JENKINS ON K8S (MINIKUBE)

# STEP BY STEP

PRE-REQUISITES
- minikube
- kubectl
---
NAMESPACE AND SERVICE CREATION
```
$ kubectl apply -f jenkins-setup-k8s.yaml
```
`jenkins-setup-k8s.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: jenkins
  labels:
    name: jenkins
---
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: jenkins
spec:
  type: NodePort
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: jenkins
``` 
---
DEPLOYMENT
```
$ kubectl apply -f deployment.yaml
```
`deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts-jdk11
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
      volumes:
      - name: jenkins-home
        emptyDir: { }
```
---
GET MINIKUBE IP
```
$ minikube ip
```
---
GET PORT FROM SERVICE
```
$ kubectl get service
````
---
GET ADMIN PASSWORD
```
$ kubectl logs pod_name
```
---
OPEN YOUR BROWSER

`$ minikube_ip:random_port_from_service` - The default node port range for Kubernetes is 30000 - 32767