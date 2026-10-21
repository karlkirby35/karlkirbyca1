# Pushing a change 
1:
    docker build --platform linux/amd64 \
  -t 974280729622.dkr.ecr.eu-west-1.amazonaws.com/karlkirbyca1-frontend:latest \
  ./frontend

2:
    docker push 974280729622.dkr.ecr.eu-west-1.amazonaws.com/karlkirbyca1-frontend:latest

3:
    aws ssm start-session --target i-09681537122f49f19 --region eu-west-1

4:
    aws ecr get-login-password --region eu-west-1 \
  | sudo docker login --username AWS --password-stdin 974280729622.dkr.ecr.eu-west-1.amazonaws.com

5:
    sudo docker stop karlkirbyca1-frontend
    sudo docker rm karlkirbyca1-frontend

    sudo docker run -d \
    --name karlkirbyca1-frontend \
    --network karlkirbyca1-network \
    --restart unless-stopped \
    -p 80:80 \
    974280729622.dkr.ecr.eu-west-1.amazonaws.com/karlkirbyca1-frontend:latest

6:
    sudo docker ps