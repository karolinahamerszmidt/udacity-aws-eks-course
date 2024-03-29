# Deploying a Flask API

This is the project starter repo for the course Server Deployment, Containerization, and Testing.

In this project you will containerize and deploy a Flask API to a Kubernetes cluster using Docker, AWS EKS, CodePipeline, and CodeBuild.

The Flask app that will be used for this project consists of a simple API with three endpoints:

- `GET '/'`: This is a simple health check, which returns the response 'Healthy'. 
- `POST '/auth'`: This takes a email and password as json arguments and returns a JWT based on a custom secret.
- `GET '/contents'`: This requires a valid JWT, and returns the un-encrpyted contents of that token. 

The app relies on a secret set as the environment variable `JWT_SECRET` to produce a JWT. The built-in Flask server is adequate for local development, but not production, so you will be using the production-ready [Gunicorn](https://gunicorn.org/) server when deploying the app.



## Prerequisites

* Docker Desktop - Installation instructions for all OSes can be found <a href="https://docs.docker.com/install/" target="_blank">here</a>.
* Git: <a href="https://git-scm.com/downloads" target="_blank">Download and install Git</a> for your system. 
* Code editor: You can <a href="https://code.visualstudio.com/download" target="_blank">download and install VS code</a> here.
* AWS Account
* Python version between 3.7 and 3.9. Check the current version using:
```bash
#  Mac/Linux/Windows 
python --version
```
You can download a specific release version from <a href="https://www.python.org/downloads/" target="_blank">here</a>.

* Python package manager - PIP 19.x or higher. PIP is already installed in Python 3 >=3.4 downloaded from python.org . However, you can upgrade to a specific version, say 20.2.3, using the command:
```bash
#  Mac/Linux/Windows Check the current version
pip --version
# Mac/Linux
pip install --upgrade pip==20.2.3
# Windows
python -m pip install --upgrade pip==20.2.3
```
* Terminal
   * Mac/Linux users can use the default terminal.
   * Windows users can use either the GitBash terminal or WSL. 
* Command line utilities:
  * AWS CLI installed and configured using the `aws configure` command. Another important configuration is the region. Do not use the us-east-1 because the cluster creation may fails mostly in us-east-1. Let's change the default region to:
  ```bash
  aws configure set region us-east-2  
  ```
  Ensure to create all your resources in a single region. 
  * EKSCTL installed in your system. Follow the instructions [available here](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html#installing-eksctl) or <a href="https://eksctl.io/introduction/#installation" target="_blank">here</a> to download and install `eksctl` utility. 
  * The KUBECTL installed in your system. Installation instructions for kubectl can be found <a href="https://kubernetes.io/docs/tasks/tools/install-kubectl/" target="_blank">here</a>. 


## Initial setup

1. Fork the <a href="https://github.com/udacity/cd0157-Server-Deployment-and-Containerization" target="_blank">Server and Deployment Containerization Github repo</a> to your Github account.
1. Locally clone your forked version to begin working on the project.
```bash
git clone https://github.com/SudKul/cd0157-Server-Deployment-and-Containerization.git
cd cd0157-Server-Deployment-and-Containerization/
```
1. These are the files relevant for the current project:
```bash
.
├── Dockerfile 
├── README.md
├── aws-auth-patch.yml #ToDo
├── buildspec.yml      #ToDo
├── ci-cd-codepipeline.cfn.yml #ToDo
├── iam-role-policy.json  #ToDo
├── main.py
├── requirements.txt
├── simple_jwt_api.yml
├── test_main.py  #ToDo
└── trust.json     #ToDo 
```

     
## Project Steps

Completing the project involves several steps:

1. Write a Dockerfile for a simple Flask API
2. Build and test the container locally
3. Create an EKS cluster
4. Store a secret using AWS Parameter Store
5. Create a CodePipeline pipeline triggered by GitHub checkins
6. Create a CodeBuild stage which will build, test, and deploy your code

For more detail about each of these steps, see the project lesson.

## Notes

Login to AWS. (use credentials from the course / region: us-east-1 / format: json)

```bash
aws configure
```

This is not enought. After that you have to add a token to credentials file:

```bash
code ~/.aws/credentials

# Add this line at the end of the file
aws_session_token = YOUR_TOKEN_HERE
```

Create cluster

```bash
eksctl create cluster --name eksctl-demo --nodes=2 --version=1.29 --instance-types=t2.micro --region=us-east-2
```

Delete cluster:

```bash
eksctl delete cluster eksctl-demo  --region=us-east-2
```

If your kubectl connection expired you need to update the config:

```bash
aws eks update-kubeconfig --region us-east-2 --name eksctl-demo
```

Get AWS user id. (Mine is "046017406246")

```bash
aws sts get-caller-identity --query Account --output text
```

Create an IAM role that will connect EKS with CodeBuild:

```bash
aws iam create-role --role-name UdacityFlaskDeployCBKubectlRole --assume-role-policy-document file://trust.json --output text --query 'Role.Arn'
```

Now attach a policy to that role:

```bash
aws iam put-role-policy --role-name UdacityFlaskDeployCBKubectlRole --policy-name eks-describe --policy-document file://iam-role-policy.json
```

Write down the cureent EKS settings to some temp file:

```bash
kubectl get -n kube-system configmap/aws-auth -o yaml > /tmp/aws-auth-patch.yml
```

Edit the config:

```bash
code /System/Volumes/Data/private/tmp/aws-auth-patch.yml
```

Add the following next to other similar one:

```yaml
- groups:
   	- system:masters
   	rolearn: arn:aws:iam::046017406246:role/UdacityFlaskDeployCBKubectlRole
   	username: build  
```

Path the file:

```bash
kubectl patch configmap/aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yml)"
```

Now I'm creating a stack based on the file `./ci-cd-codepipeline.cfn.yml`.

When creating Cloud Formation stack for the pipeline I got the error "The runtime parameter of python3.7 is no longer supported" so I updated the runtime to 3.8.

When creating "myPipeline" the process got stuck when creating "KubectlAssumeRoleCustomResource". After an hour of waiting I decided to delete the stack but it got stuck deleting the pipeline...

I'm trying to create another stack "myPipeline2".

The other pipeline also didn't worked. But I found that the lambda was failing with the error "AttributeError: module 'botocore.vendored.requests' has no attribute 'put'" so I tried to change the import from "from botocore.vendored import requests" to "import requests".

Ok, so we can't use "requests" without installing them and zipping the code but I will try to use "urllib3" library instead. That worked!

Now the problem was that deployment on k8s was stuck - probably 3 replicas are too much for my 2 micro nodes. Also, the image that was deployed was some random persons image and not the one I was building so I updated that as well.

Now I see that flask app is crashing in k8s because of outdated version of flask. I will try with a newer version.

Pushing a secret to AWS:

```bash
aws ssm put-parameter --name JWT_SECRET --overwrite --value "myjwtsecret" --type SecureString --region us-east-2
```

Check if the secret is there:

```bash
aws ssm get-parameter --name JWT_SECRET --region us-east-2
```

To delete the secret:

```bash
aws ssm delete-parameter --name JWT_SECRET --region us-east-2
```

Added k8s service to deployment.yml file.

Create and activate conda env:

```bash
conda create --name aws-app python=3.8
conda activate aws-app
```

When running buildspec with pythin 3.8 "awscli" fails with "module 'lib' has no attribute 'X509_V_FLAG_NOTIFY_POLICY'". Gonna try to run it on old python 3.7.

Seems that what solved all the random problems with build pipeline was switching to "aws/codebuild/standard:5.0" and python 3.8.