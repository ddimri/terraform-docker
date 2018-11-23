# Automatic Deployment using Docker container
```
Spin up an EC2 instance
sudo wget -qO- https://get.docker.com/ | sh
sudo usermod -aG docker ubuntu
sudo sh -c "echo 'net.ipv4.conf.all.route_localnet = 1' >> /etc/sysctl.conf"
sudo sysctl -p /etc/sysctl.conf
sudo iptables -t nat -A PREROUTING -p tcp -d 169.254.170.2 --dport 80 -j DNAT --to-destination 127.0.0.1:51679
sudo iptables -t nat -A OUTPUT -d 169.254.170.2 -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 51679
sudo apt-get install iptables-persistent -y
sudo sh -c 'iptables-save > /etc/iptables/rules.v4'
sudo mkdir -p /etc/ecs && sudo touch /etc/ecs/ecs.config
sudo mkdir -p /var/log/ecs /var/lib/ecs/data
vi /etc/ecs/ecs.config
	ECS_DATADIR=/data
	ECS_ENABLE_TASK_IAM_ROLE=true
	ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
	ECS_LOGFILE=/log/ecs-agent.log
	ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs"]
	ECS_LOGLEVEL=info
	ECS_CLUSTER=docker_ecs_cluster
sudo docker run --name ecs-agent --detach=true --restart=on-failure:10 --volume=/var/run:/var/run --volume=/var/log/ecs/:/log --volume=/var/lib/ecs/data:/data --volume=/etc/ecs:/etc/ecs --net=host --env-file=/etc/ecs/ecs.config amazon/amazon-ecs-agent:latest

Create an AMI
```
Follow these instrictions/commands on your Local machine

```

# Doker installation
To install Docker on an Amazon Linux instance

sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
#logout and log back in
docker info

mkdir aws-training
cd aws-training
vi Dockerfile
	FROM nginx:alpine
	COPY . /usr/share/nginx/html
vi index.html
	<p><font face="verdana" color="blue">Welcome to AWS Training!</font></p>

docker build -t aws-training .

git clone https://github.com/ddimri/static-app
git push --mirror <your github repo>

Create ECR  named 'aws-training' to store Docker images
aws ecr get-login --region us-west-2 --profile deepakprasad
docker login
docker build -t aws-training .
docker tag static-app:latest 398818754185.dkr.ecr.us-west-2.amazonaws.com/aws-training:latest
docker push 398818754185.dkr.ecr.us-west-2.amazonaws.com/aws-training:latest
docker run -d --name aws-training -p 80:80 aws-training


terraform
==========

install terraform --> Download terraform https://www.terraform.io/downloads.html
mkdir terraform
git clone https://github.com/ddimri/terraform-docker

cd certs
aws iam upload-server-certificate --server-certificate-name docker-hello-world --certificate-body file://aws.training.com.cert.pem --certificate-chain file://ca-chain.cert.pem --private-key file://aws.training.com.key --profile deepakprasad

update variable.tf
update task-definition file
```
