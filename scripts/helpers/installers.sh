#!/usr/bin/env bash

function installFluentBit {
    #kubectl apply -f ./config/tiller-serviceaccount.yaml
    #helm init --service-account tiller

    echo
    echo "${green}Creating logging namespace and cluster setup...${reset}"
    kubectl create namespace logging
    kubectl config set-context $(kubectl config current-context) --namespace=logging

    WORK_DIR=../via-k8s/config

    # Fluent Bit must be deployed as a DaemonSet, so on that way it will be available on every node of your Kubernetes cluster.
    # To get started run the following commands to create the namespace, service account and role setup:
    echo
    echo "${green}Setting up fluent-bit...${reset}"
    kubectl apply -f ${WORK_DIR}/fluent-bit-service-account.yaml
    kubectl apply -f ${WORK_DIR}/fluent-bit-role.yaml
    kubectl apply -f ${WORK_DIR}/fluent-bit-role-binding.yaml

    # The next step is to create a ConfigMap that will be used by our Fluent Bit DaemonSet:
    kubectl apply -f ${WORK_DIR}/fluent-bit-configmap.yaml

    # The next step is to create a ConfigMap that will be used to make certificates available on the DaemonSet:
    kubectl apply -f ${WORK_DIR}/fluent-bit-configmap-certs.yaml

    # Fluent Bit to Elasticsearch on Minikube - use custom version of config that uses 10.0.2.2 as the hostname for Elasticsearch
    kubectl apply -f ${WORK_DIR}/fluent-bit-ds-minikube.yaml
}

function installApache {
    echo
    echo "${green}Creating webserver namespace and cluster setup...${reset}"
    kubectl create namespace webserver
    kubectl config set-context $(kubectl config current-context) --namespace=webserver

    echo
    echo "${green}Create a deployment of two Apache pods...${reset}"
    kubectl apply -f ${WORK_DIR}/apache.yaml
}

function installRedis {
    echo
    echo "${green}Creating redis namespace and cluster setup...${reset}"
    kubectl create namespace redis
    kubectl config set-context $(kubectl config current-context) --namespace=redis

    WORK_DIR=../via-k8s/config

    echo
    echo "${green}Configuring Redis cluster...${reset}"
    kubectl create -f ${WORK_DIR}/redis-master.yaml

    echo
    echo "${green}Launching Redis master...${reset}"
    continueAfterContainerCreated redis name=redis

    echo
    echo "${green}Setting up Redis sentinel...${reset}"
    kubectl create -f ${WORK_DIR}/redis-sentinel-service.yaml
    kubectl create -f ${WORK_DIR}/redis-controller.yaml
    kubectl create -f ${WORK_DIR}/redis-sentinel-controller.yaml

    echo
    echo "${green}Scale Redis pods to 3...${reset}"
    kubectl scale rc redis --replicas=3
    kubectl scale rc redis-sentinel --replicas=3

    #kubectl delete pods redis-master
}