Steps :
sudo -u ubuntu minikube start --driver=docker
sudo -u ubuntu minikube stop
sudo -u ubuntu kubectl get nodes
sudo -u ubuntu kubectl get pods -n airflow
