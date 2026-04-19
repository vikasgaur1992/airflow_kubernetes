provider "aws" {
  region = "us-east-1"
}

# 1. Security Group for SSH and Airflow UI
resource "aws_security_group" "airflow_sg" {
  name        = "airflow-k8s-sg"
  description = "Allow SSH and Airflow Web UI"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Recommendation: Replace with your IP/32
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. EC2 Instance Provisioning
resource "aws_instance" "airflow_server" {
  ami           = "ami-0c7217cdde317cfec" # Ubuntu 22.04 LTS
  instance_type = "t3.large"             # Recommended min for Minikube
  key_name      = "ltim"                  # Your existing key
  
# --- ADD THIS BLOCK ---
  root_block_device {
    volume_size           = 50    # Increase to 30GB
    volume_type           = "gp2" # General Purpose SSD (newer/faster)
    delete_on_termination = true
  }

  vpc_security_group_ids = [aws_security_group.airflow_sg.id]

  tags = {
    Name = "Airflow-Kubernetes-Node"
  }

  # Connection block for provisioners
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("/Users/vikas/Desktop/aws_access/ltim.pem") # Ensure this file is in your local directory
    host        = self.public_ip
  }

  # 3. Remote Execution to Install K8s and Airflow
provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install -y docker.io",
      "sudo usermod -aG docker ubuntu",
      
      # Install Minikube
      "curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64",
      "sudo install minikube-linux-amd64 /usr/local/bin/minikube",
      
      # Install Kubectl
      "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
      "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl",

      # Start Minikube (as ubuntu user)
      "sudo -u ubuntu minikube start --driver=docker",

      # Wait for K8s API to be responsive
      "echo 'Waiting for cluster...' ",
      "timeout 300s bash -c 'until sudo -u ubuntu kubectl get nodes; do sleep 5; done'",

      # Install Helm
      "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash",

      # Add Airflow Helm Repo and Install
      "sudo -u ubuntu helm repo add apache-airflow https://airflow.apache.org",
      "sudo -u ubuntu helm repo update",
      "sudo -u ubuntu kubectl create namespace airflow || true",
      "sudo -u ubuntu helm install airflow apache-airflow/airflow --namespace airflow --set executor=KubernetesExecutor --timeout 15m0s"
    ]
  }
}

# 4. Output the Public IP to access your server
output "airflow_public_ip" {
  value = aws_instance.airflow_server.public_ip
}