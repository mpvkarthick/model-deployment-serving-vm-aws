#!/bin/bash

# ============================================================================
# Intent Classifier Production Deployment Script
# ============================================================================
# Deploys Intent Classifier with ALB, ASG, and multi-AZ setup
# 
# Prerequisites:
#   - VPC with two subnets in different availability zones
#   - EC2 Key Pair created in your AWS account
#   - AWS CLI configured with appropriate credentials
#
# Usage:
#   ./run-cf-script.sh
#
# ============================================================================

aws cloudformation create-stack \
  --region us-east-1 \
  --stack-name intent-hw-prod-stack \
  --template-body file://intent-hw-app-enhanced.yaml \
  --parameters \
    ParameterKey=VpcId,ParameterValue=vpc-0fa98310161390c2f \
    ParameterKey=SubnetId1,ParameterValue=subnet-007c14473b2f0fd65 \
    ParameterKey=SubnetId2,ParameterValue=subnet-0bfef3794d44aeecf \
    ParameterKey=KeyName,ParameterValue=intent-app-key \
    ParameterKey=EnvironmentName,ParameterValue=production \
    ParameterKey=MinSize,ParameterValue=2 \
    ParameterKey=DesiredCapacity,ParameterValue=2 \
    ParameterKey=MaxSize,ParameterValue=6 \
    ParameterKey=InstanceType,ParameterValue=t3.small \
  --capabilities CAPABILITY_NAMED_IAM

# ============================================================================
# Post-deployment verification commands
# ============================================================================
# Uncomment to automatically check stack status:
#
# echo "Waiting for stack creation..."
# aws cloudformation wait stack-create-complete --stack-name intent-hw-prod-stack --region us-east-1
# 
# echo "Stack created successfully! Getting outputs..."
# aws cloudformation describe-stacks \
#   --stack-name intent-hw-prod-stack \
#   --region us-east-1 \
#   --query 'Stacks[0].Outputs' \
#   --output table
#
# ============================================================================
