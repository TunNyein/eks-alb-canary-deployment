# EKS Blue/Green Deployment with Datadog Monitoring

## Overview

This repository demonstrates a Blue/Green deployment strategy on Amazon EKS using:

BookInfo microservices, deployed in separate namespaces

AWS Load Balancer Controller (LBC) for gradual traffic shifting

IAM Roles for lead & junior engineers, enforced through EKS access policies + RBAC

Datadog for full-stack monitoring (infrastructure, cluster, and application)

The cluster runs in private subnets, and all administrative access is done using EKS API access.

A detailed operational workflow is available in: eks-blue-greee-runbook.md

## Architecture
assets/architecture.png

## Cleanup

terraform destroy 

