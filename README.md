# Intent Classifier - ML Model Deployment on AWS

Complete production-ready infrastructure and deployment automation for the Intent Classifier ML model on AWS using EC2, Auto Scaling, and Application Load Balancer.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment Options](#deployment-options)
- [API Usage](#api-usage)
- [Monitoring](#monitoring)
- [Cleanup](#cleanup)

---

## 🎯 Overview

This project provides:

✅ **Infrastructure as Code (IaC)**: CloudFormation templates for reproducible AWS deployments  
✅ **Auto Scaling**: Automatically scales from 2-6 EC2 instances based on demand  
✅ **Multi-AZ**: High availability across multiple availability zones  
✅ **Load Balancing**: Application Load Balancer distributes traffic  
✅ **Health Checks**: Automatic instance health verification  
✅ **User Data Automation**: EC2 instances auto-configure with Gunicorn + Nginx  

---

## 🏗️ Architecture

```
Internet
   ↓
   └─ HTTP (Port 80)
      ↓
   ┌─ Application Load Balancer ─────────┐
   │  (Distributes traffic across AZs)   │
   └──────────────────┬──────────────────┘
                      ↓
           Target Group (Health: /health)
                      ↓
      ┌──────────────────────────────────┐
      │   Auto Scaling Group (Min:2)     │
      │                                   │
      ├─ AZ-a: EC2 Instance              │
      │  └─ Nginx (Reverse Proxy)         │
      │     └─ Gunicorn (WSGI Server)    │
      │        └─ Flask App + ML Model    │
      │                                   │
      └─ AZ-b: EC2 Instance              │
         └─ Nginx (Reverse Proxy)         │
            └─ Gunicorn (WSGI Server)    │
               └─ Flask App + ML Model    │
      └──────────────────────────────────┘
```

---

## 📋 Prerequisites

### Required
- AWS Account with appropriate IAM permissions
- VPC with at least 2 subnets in different availability zones
- EC2 Key Pair created in your AWS account
- AWS CLI v2 configured with credentials

### Optional
- Git for cloning the repository
- curl for testing API endpoints

---

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/mpvkarthick/model-deployment-serving-vm-aws.git
cd model-deployment-serving-vm-aws
```

### 2. Deploy the Stack

```bash
./run-cf-script.sh
```

Or manually create the stack:

```bash
aws cloudformation create-stack \
  --region us-east-1 \
  --stack-name intent-hw-prod-stack \
  --template-body file://intent-hw-app-enhanced.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=vpc-xxxxxxxx \
    ParameterKey=SubnetId1,ParameterValue=subnet-xxxxxxxx \
    ParameterKey=SubnetId2,ParameterValue=subnet-yyyyyyyy \
    ParameterKey=KeyName,ParameterValue=your-key-pair-name \
  --capabilities CAPABILITY_NAMED_IAM
```

### 3. Wait for Deployment (10-15 minutes)

```bash
aws cloudformation wait stack-create-complete \
  --stack-name intent-hw-prod-stack \
  --region us-east-1
```

### 4. Get the Load Balancer DNS

```bash
aws cloudformation describe-stacks \
  --stack-name intent-hw-prod-stack \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[0].OutputValue' \
  --output text
```

---

## 🔧 Deployment Options

### Option 1: Automatic (Recommended)

Use the provided deployment script:

```bash
./run-cf-script.sh
```

**What it does**:
- Creates 2-6 EC2 instances across 2 availability zones
- Sets up Application Load Balancer
- Configures Auto Scaling Group
- Deploys Nginx + Gunicorn + Flask on each instance
- Sets up health checks and automatic instance registration

### Option 2: Manual CloudFormation

```bash
aws cloudformation create-stack \
  --stack-name intent-hw-prod \
  --template-body file://intent-hw-app-enhanced.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=vpc-xxxxxxxx \
    ParameterKey=SubnetId1,ParameterValue=subnet-xxxxxxxx \
    ParameterKey=SubnetId2,ParameterValue=subnet-yyyyyyyy \
    ParameterKey=KeyName,ParameterValue=your-key-name \
    ParameterKey=EnvironmentName,ParameterValue=production \
    ParameterKey=InstanceType,ParameterValue=t3.small \
    ParameterKey=MinSize,ParameterValue=2 \
    ParameterKey=DesiredCapacity,ParameterValue=2 \
    ParameterKey=MaxSize,ParameterValue=6 \
  --capabilities CAPABILITY_NAMED_IAM
```

### Option 3: AWS Console

1. Go to CloudFormation in AWS Console
2. Click "Create Stack"
3. Choose "Upload a template file"
4. Select `intent-hw-app-enhanced.yaml`
5. Fill in parameters
6. Review and create

---

## 🔌 API Usage

### Get Load Balancer URL

```bash
ALB_URL=$(aws cloudformation describe-stacks \
  --stack-name intent-hw-prod-stack \
  --query 'Stacks[0].Outputs[0].OutputValue' \
  --output text)
echo "ALB URL: $ALB_URL"
```

### Health Check Endpoint

**Check if the service is healthy**:

```bash
curl -X GET http://${ALB_URL}/health
```

**Expected Response**:
```json
{"status": "ok"}
```

### Predict Endpoint

**Send an intent classification request**:

```bash
curl -X POST http://${ALB_URL}/predict \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, how are you?"}'
```

**Example Requests**:

```bash
# Weather intent
curl -X POST http://${ALB_URL}/predict \
  -H "Content-Type: application/json" \
  -d '{"text": "What is the weather today?"}'

# Greeting intent
curl -X POST http://${ALB_URL}/predict \
  -H "Content-Type: application/json" \
  -d '{"text": "Hi there!"}'

# Help intent
curl -X POST http://${ALB_URL}/predict \
  -H "Content-Type: application/json" \
  -d '{"text": "I need help with something"}'
```

**Expected Response**:
```json
{
  "intent": "greeting",
  "confidence": 0.95
}
```

---

## 📊 Monitoring

### Check Stack Status

```bash
aws cloudformation describe-stacks \
  --stack-name intent-hw-prod-stack \
  --query 'Stacks[0].StackStatus'
```

### View Auto Scaling Group

```bash
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names intent-asg-production \
  --query 'AutoScalingGroups[0].[MinSize, DesiredCapacity, MaxSize, Instances[].InstanceId]'
```

### Check Target Group Health

```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws cloudformation describe-stacks \
    --stack-name intent-hw-prod-stack \
    --query 'Stacks[0].Outputs[?OutputKey==`TargetGroupArn`].OutputValue' \
    --output text)
```

### SSH into an Instance

```bash
# Get instance ID
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names intent-asg-production \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

# SSH (requires instance to have public IP or bastion host)
ssh -i your-key.pem ubuntu@${INSTANCE_ID}

# Check application status
sudo systemctl status intent_gunicorn
sudo systemctl status nginx

# View application logs
sudo journalctl -u intent_gunicorn -f
```

---

## 📁 Project Structure

```
model-deployment-serving-vm-aws/
├── README.md                          # This file
├── app.py                             # Flask application
├── wsgi.py                            # WSGI entry point for Gunicorn
├── requirements.txt                   # Python dependencies
├── userdata.sh                        # EC2 initialization script
├── intent-hw-app-enhanced.yaml        # CloudFormation template
├── run-cf-script.sh                   # Deployment script
├── intent-hw-app-key.pem              # EC2 Key Pair (DO NOT COMMIT)
└── model/
    ├── intent_model.py                # Intent classification model
    └── train.py                       # Model training script
```

---

## 🔑 Configuration Parameters

### CloudFormation Template Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `VpcId` | String | Required | VPC ID for deployment |
| `SubnetId1` | String | Required | Subnet in AZ-a |
| `SubnetId2` | String | Required | Subnet in AZ-b (different AZ) |
| `KeyName` | String | Required | EC2 Key Pair name |
| `SSHCidr` | String | 0.0.0.0/0 | CIDR allowed for SSH |
| `InstanceType` | String | t3.small | EC2 instance type |
| `EnvironmentName` | String | production | Environment identifier |
| `MinSize` | Number | 2 | Minimum instances |
| `DesiredCapacity` | Number | 2 | Desired running instances |
| `MaxSize` | Number | 6 | Maximum instances |

---

## 🛠️ Customization

### Change Instance Type

```bash
aws cloudformation update-stack \
  --stack-name intent-hw-prod-stack \
  --use-previous-template \
  --parameters ParameterKey=InstanceType,ParameterValue=t3.medium
```

### Scale Up Instances

```bash
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name intent-asg-production \
  --desired-capacity 4
```

### Update Application Code

```bash
# SSH into instance
ssh -i your-key.pem ubuntu@instance-ip

# Pull latest code
cd /opt/intent-hw-app
git pull origin main

# Restart application
sudo systemctl restart intent_gunicorn
```

---

## 🧹 Cleanup

### Delete the CloudFormation Stack

```bash
aws cloudformation delete-stack \
  --stack-name intent-hw-prod-stack \
  --region us-east-1
```

### Verify Deletion

```bash
aws cloudformation describe-stacks \
  --stack-name intent-hw-prod-stack \
  --region us-east-1
```

This will delete:
- ✅ EC2 instances
- ✅ Application Load Balancer
- ✅ Target Group
- ✅ Auto Scaling Group
- ✅ Security Groups
- ✅ IAM Role and Instance Profile
- ✅ Launch Template

---

## 📝 Files Description

### `intent-hw-app-enhanced.yaml`
Production-grade CloudFormation template with:
- Multi-AZ VPC setup
- Security Groups (ALB + EC2)
- IAM roles and instance profiles
- Launch Template with user data
- Application Load Balancer
- Target Group with health checks
- Auto Scaling Group
- Comprehensive documentation

### `userdata.sh`
EC2 instance initialization script that:
- Updates system packages
- Installs Git, Python, Nginx
- Clones application repository
- Creates Python virtual environment
- Installs dependencies (Flask, Gunicorn)
- Trains ML model
- Configures Gunicorn systemd service
- Configures Nginx reverse proxy
- Starts all services

### `run-cf-script.sh`
Automated deployment script that:
- Creates CloudFormation stack
- Passes all required parameters
- Enables IAM capabilities
- Deploys production-ready infrastructure

### `app.py`
Flask application with endpoints:
- `GET /health` - Health check
- `POST /predict` - Intent prediction

### `model/intent_model.py`
Intent classification model that predicts user intent from text

---

## 🔒 Security Best Practices

✅ **Implemented**:
- Instances only accessible via ALB or SSM Session Manager
- IAM roles with least privilege
- Security groups restrict traffic
- SSH access controlled via CIDR blocks

⚠️ **Recommended for Production**:
- [ ] Enable HTTPS/SSL via AWS Certificate Manager
- [ ] Use AWS Secrets Manager for sensitive data
- [ ] Enable VPC Flow Logs for network monitoring
- [ ] Use AWS WAF for DDoS protection
- [ ] Enable CloudTrail for audit logging
- [ ] Implement cross-region replication for disaster recovery

---

## 🐛 Troubleshooting

### Stack Creation Failed

**Check events**:
```bash
aws cloudformation describe-stack-events \
  --stack-name intent-hw-prod-stack \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'
```

### Instances Not Healthy

**Check target group health**:
```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

### Application Not Responding

**SSH into instance and check services**:
```bash
ssh -i your-key.pem ubuntu@instance-ip

# Check Gunicorn
sudo systemctl status intent_gunicorn
sudo journalctl -u intent_gunicorn -n 50

# Check Nginx
sudo systemctl status nginx
sudo nginx -t
```

### Health Check Failing

**Test manually**:
```bash
curl -v http://alb-dns/health
```

---

## 📚 Additional Resources

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [EC2 User Data Guide](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)
- [Application Load Balancer Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [Auto Scaling Groups](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html)
- [Gunicorn Documentation](https://gunicorn.org/)
- [Nginx Documentation](https://nginx.org/)

---

## 📄 License

This project is open source and available under the MIT License.

---

## 👨‍💻 Author

**Karthick** - ML/DevOps Engineer  
GitHub: [@mpvkarthick](https://github.com/mpvkarthick)

---

## 📞 Support

For issues, questions, or contributions:
1. Open an issue on GitHub
2. Check the Troubleshooting section
3. Review CloudFormation stack events for detailed error messages

---

**Last Updated**: January 26, 2026  
**AWS Region**: us-east-1  
**Architecture**: Multi-AZ ALB + ASG
