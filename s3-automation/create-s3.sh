#!/bin/bash

# Setting Bucket Name 
BUCKET_NAME="my-bucket-$(date +%s)"

# Create S3 Bucket

aws s3 mb s3://$BUCKET_NAME --region us-east-2 

# confirm creation

aws s3 ls



