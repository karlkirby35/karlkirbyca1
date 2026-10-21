# 

# Pushing a change 
1: Builds new image

    docker build --platform linux/amd64 \
  -t 974280729622.dkr.ecr.eu-west-1.amazonaws.com/karlkirbyca1-frontend:latest \
  ./frontend

2:  Push image to AWS ECR 

    docker push 974280729622.dkr.ecr.eu-west-1.amazonaws.com/karlkirbyca1-frontend:latest

3: Connects to EC2 instance

    aws ssm start-session --target i-09681537122f49f19 --region eu-west-1

4.1 : Log into ECR  

    aws ecr get-login-password --region eu-west-1 \
  | sudo docker login --username AWS --password-stdin 974280729622.dkr.ecr.eu-west-1.amazonaws.com

4.2: Pull image

sudo docker pull 974280729622.dkr.ecr.eu-west-1.amazonaws.com/karlkirbyca1-frontend:latest

5.1:  Stop and remove old container

    sudo docker stop karlkirbyca1-frontend
    sudo docker rm karlkirbyca1-frontend

5.2: Running updated container

    sudo docker run -d \
    --name karlkirbyca1-frontend \
    --network karlkirbyca1-network \
    --restart unless-stopped \
    -p 80:80 \
    974280729622.dkr.ecr.eu-west-1.amazonaws.com/karlkirbyca1-frontend:latest

6:  Verify

    sudo docker ps