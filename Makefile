
# Use this tag to build a customized local image

SWIFT_VERSION?=5.1.3
LAYER_VERSION?=5-1-3
# SWIFT_VERSION=5.0.3
# LAYER_VERSION=5-0-3
DOCKER_TAG=nio-swift:$(SWIFT_VERSION)
SWIFT_DOCKER_IMAGE=$(DOCKER_TAG)
SWIFT_LAMBDA_LIBRARY=nio-swift-lambda-runtime-$(LAYER_VERSION)
SWIFT_CONFIGURATION=release

# Configuration

# HelloWorld Example Configuration
SWIFT_EXECUTABLE?=HelloWorld
SWIFT_PROJECT_PATH?=Examples/HelloWorld
LAMBDA_FUNCTION_NAME?=HelloWorld
LAMBDA_HANDLER?=$(SWIFT_EXECUTABLE).helloWorld

# HTTPSRequest Example Configuration
# SWIFT_EXECUTABLE=HTTPSRequest
# SWIFT_PROJECT_PATH=Examples/HTTPSRequest
# LAMBDA_FUNCTION_NAME=HTTPSRequest
# LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).getHttps

# S3Test Example Configuration
# SWIFT_EXECUTABLE=S3Test
# SWIFT_PROJECT_PATH=Examples/S3Test
# LAMBDA_FUNCTION_NAME=S3Test
# LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).getObject

# RedisDemo Example Configuration
# SWIFT_EXECUTABLE?=RedisDemo
# SWIFT_PROJECT_PATH?=Examples/RedisDemo
# LAMBDA_FUNCTION_NAME?=RedisDemo
# LAMBDA_HANDLER?=$(SWIFT_EXECUTABLE).setGet

# PostgreSQLDemo Example Configuration
# SWIFT_EXECUTABLE=PostgreSQLDemo
# SWIFT_PROJECT_PATH=Examples/PostgreSQLDemo
# LAMBDA_FUNCTION_NAME=PostgreSQLDemo
# LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).query

# AWS Configuration
IAM_ROLE_NAME?=lambda_sprinter_basic_execution
AWS_PROFILE?=default
AWS_BUCKET?=aws-lambda-swift-sprinter

# Internals
LAMBDA_ZIP=lambda.zip
SHARED_LIBS_FOLDER=swift-shared-libs
LAYER_ZIP=swift-lambda-runtime-$(LAYER_VERSION).zip
ROOT_BUILD_PATH=./.build
LAYER_BUILD_PATH=$(ROOT_BUILD_PATH)/layer
LAMBDA_BUILD_PATH=$(ROOT_BUILD_PATH)/lambda
LOCAL_LAMBDA_PATH=$(ROOT_BUILD_PATH)/local
LOCALSTACK_TMP=$(ROOT_BUILD_PATH)/.tmp
TMP_BUILD_PATH=$(ROOT_BUILD_PATH)/tmp
DATETIME=$(shell date +'%y%m%d-%H%M%S')

# use this for local development
MOUNT_ROOT=$(shell pwd)/..
DOCKER_PROJECT_PATH=aws-lambda-swift-sprinter/$(SWIFT_PROJECT_PATH)

# normal development
# MOUNT_ROOT=$(shell pwd)
# DOCKER_PROJECT_PATH=$(SWIFT_PROJECT_PATH)

swift_test:
	docker run \
			--rm \
			--volume "$(MOUNT_ROOT):/src" \
			--workdir "/src/$(DOCKER_PROJECT_PATH)" \
			$(SWIFT_DOCKER_IMAGE) \
			swift test

clean_lambda:
	rm $(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) || true
	rm -rf $(SWIFT_PROJECT_PATH)/.build || true

#docker commands
docker_bash:
	docker run \
			-it \
			--rm \
			--volume "$(MOUNT_ROOT):/src" \
			--workdir "/src/" \
			$(SWIFT_DOCKER_IMAGE) \
			/bin/bash

docker_debug:
	docker run \
			--cap-add=SYS_PTRACE --security-opt seccomp=unconfined --security-opt apparmor=unconfined \
			-it \
			--rm \
			--volume "$(MOUNT_ROOT)/:/src" \
			--workdir "/src/$(DOCKER_PROJECT_PATH)" \
			$(SWIFT_DOCKER_IMAGE) \
			/bin/bash
			
docker_build:
	docker build --tag $(DOCKER_TAG) docker/$(SWIFT_VERSION)/.

extract_libraries:
	docker run \
			-it \
			--rm \
			--volume "$(MOUNT_ROOT)/:/src" \
			--workdir "/src/$(DOCKER_PROJECT_PATH)" \
			$(SWIFT_DOCKER_IMAGE) \
			/bin/bash -c "ldd .build/$(SWIFT_CONFIGURATION)/$(SWIFT_EXECUTABLE) | grep so | sed -e '/^[^\t]/ d' | sed -e 's/\t//' | sed -e 's/(0.*)//'"

build_lambda:
	docker run \
			--rm \
			--volume "$(MOUNT_ROOT)/:/src" \
			--workdir "/src/$(DOCKER_PROJECT_PATH)" \
			$(SWIFT_DOCKER_IMAGE) \
			/bin/bash -c "swift build --configuration $(SWIFT_CONFIGURATION)"

test_package:
	docker run \
			--rm \
			--volume "$(MOUNT_ROOT)/:/src" \
			--workdir "/src/" \
			$(SWIFT_DOCKER_IMAGE) \
			swift test

create_build_directory:
	if [ ! -d "$(LAMBDA_BUILD_PATH)" ]; then mkdir -p $(LAMBDA_BUILD_PATH); fi
	if [ ! -d "$(LAYER_BUILD_PATH)" ]; then mkdir -p $(LAYER_BUILD_PATH); fi
	if [ ! -d "$(TMP_BUILD_PATH)" ]; then mkdir -p $(TMP_BUILD_PATH); fi

package_lambda: clean_lambda create_build_directory build_lambda
	zip -r -j $(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) $(SWIFT_PROJECT_PATH)/.build/$(SWIFT_CONFIGURATION)/$(SWIFT_EXECUTABLE)

clean_all: clean_layer clean_lambda
	rm -r $(ROOT_BUILD_PATH)

clean_layer:
	rm $(LAYER_BUILD_PATH)/$(LAYER_ZIP) || true
	rm -r $(SHARED_LIBS_FOLDER) || true

package_layer: create_build_directory clean_layer
	$(eval SHARED_LIBRARIES := $(shell cat docker/$(SWIFT_VERSION)/swift-shared-libraries.txt | tr '\n' ' '))
	mkdir -p $(SHARED_LIBS_FOLDER)/lib
	docker run \
			--rm \
			--volume "$(shell pwd)/:/src" \
			--workdir "/src" \
			$(SWIFT_DOCKER_IMAGE) \
			cp /lib64/ld-linux-x86-64.so.2 $(SHARED_LIBS_FOLDER)
	docker run \
			--rm \
			--volume "$(shell pwd)/:/src" \
			--workdir "/src" \
			$(SWIFT_DOCKER_IMAGE) \
			cp -t $(SHARED_LIBS_FOLDER)/lib $(SHARED_LIBRARIES)
	zip -r $(LAYER_BUILD_PATH)/$(LAYER_ZIP) bootstrap $(SHARED_LIBS_FOLDER)

upload_build_to_s3: create_lambda_s3_key
	aws s3 sync --acl public-read "$(LAMBDA_BUILD_PATH)" s3://$(AWS_BUCKET)/$(LAMBDA_S3_UPLOAD_PATH) --profile $(AWS_PROFILE)

create_layer_s3_key:
	$(eval LAYER_S3_UPLOAD_PATH := layers/$(SWIFT_LAMBDA_LIBRARY))

upload_lambda_layer_with_s3: create_layer_s3_key
	aws s3 sync --acl public-read "$(LAYER_BUILD_PATH)" s3://$(AWS_BUCKET)/$(LAYER_S3_UPLOAD_PATH) --profile $(AWS_PROFILE)
	aws lambda publish-layer-version --layer-name $(SWIFT_LAMBDA_LIBRARY) --description "AWS Custom Runtime Swift Shared Libraries with NIO" --content "S3Bucket=$(AWS_BUCKET),S3Key=$(LAYER_S3_UPLOAD_PATH)/$(LAYER_ZIP)" --output text --query LayerVersionArn --profile $(AWS_PROFILE) > $(TMP_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt
	cat $(TMP_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt

upload_lambda_layer:
	aws lambda publish-layer-version --layer-name $(SWIFT_LAMBDA_LIBRARY) --description "AWS Custom Runtime Swift Shared Libraries with NIO" --zip-file fileb://$(LAYER_BUILD_PATH)/$(LAYER_ZIP) --output text --query LayerVersionArn --profile $(AWS_PROFILE) > $(TMP_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt
	cat $(TMP_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt

create_role:
	aws iam create-role --role-name $(IAM_ROLE_NAME) --description "Allows Lambda functions to call AWS services on your behalf." --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["sts:AssumeRole"],"Principal":{"Service":["lambda.amazonaws.com"]}}]}' --profile $(AWS_PROFILE) || true
	aws iam attach-role-policy --role-name $(IAM_ROLE_NAME) --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" --profile $(AWS_PROFILE) || true
    $(eval IAM_ROLE_ARN := $(shell aws iam list-roles --query "Roles[? RoleName == '$(IAM_ROLE_NAME)'].Arn" --output text --profile $(AWS_PROFILE)))

create_lambda: create_role package_lambda
	$(eval LAMBDA_LAYER_ARN := $(shell cat $(TMP_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt))
	$(info "$(LAMBDA_LAYER_ARN)")
	aws lambda create-function --function-name $(LAMBDA_FUNCTION_NAME) --runtime provided --handler $(LAMBDA_HANDLER) --role "$(IAM_ROLE_ARN)" --zip-file fileb://$(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) --layers "$(LAMBDA_LAYER_ARN)" --profile $(AWS_PROFILE)

create_lambda_s3_key:
	$(eval LAMBDA_S3_UPLOAD_PATH := lambdas/$(LAMBDA_FUNCTION_NAME)/$(DATETIME))

create_lambda_with_s3: create_role package_lambda upload_build_to_s3
	$(eval LAMBDA_LAYER_ARN := $(shell cat $(TMP_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt))
	$(info "$(LAMBDA_LAYER_ARN)")
	aws lambda create-function --function-name $(LAMBDA_FUNCTION_NAME) --runtime provided --handler $(LAMBDA_HANDLER) --role "$(IAM_ROLE_ARN)" --code "S3Bucket=$(AWS_BUCKET),S3Key=$(LAMBDA_S3_UPLOAD_PATH)/$(LAMBDA_ZIP)" --layers "$(LAMBDA_LAYER_ARN)" --profile $(AWS_PROFILE)

update_lambda: package_lambda
	aws lambda update-function-code --function-name $(LAMBDA_FUNCTION_NAME) --zip-file fileb://$(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) --profile $(AWS_PROFILE)

update_lambda_with_s3: package_lambda upload_build_to_s3
	aws lambda update-function-code --function-name $(LAMBDA_FUNCTION_NAME) --s3-bucket $(AWS_BUCKET) --s3-key "$(LAMBDA_S3_UPLOAD_PATH)/$(LAMBDA_ZIP)" --profile $(AWS_PROFILE)

invoke_lambda:
	aws lambda invoke --function-name $(LAMBDA_FUNCTION_NAME) --profile $(AWS_PROFILE) --payload "fileb://$(SWIFT_PROJECT_PATH)/event.json" $(TMP_BUILD_PATH)/outfile && echo "\nResult:" && cat $(TMP_BUILD_PATH)/outfile && echo "\n"

create_s3_bucket:
	aws s3 mb "s3://$(AWS_BUCKET)" --profile $(AWS_PROFILE)

delete_s3_bucket:
	aws s3 ls "s3://$(AWS_BUCKET)" 2>/dev/null >/dev/null && aws s3 rb "s3://$(AWS_BUCKET)" --force 

delete_layer: 
	aws lambda list-layer-versions --layer-name nio-swift-lambda-runtime-5-1 --output text | \
		awk '{ print $$NF }' | \
		xargs aws lambda delete-layer-version --layer-name $(SWIFT_LAMBDA_LIBRARY) --version-number

nuke: clean_layer clean_lambda delete_layer
	-aws lambda get-function --function-name $(LAMBDA_FUNCTION_NAME) 2>/dev/null >/dev/null && aws lambda delete-function --function-name $(LAMBDA_FUNCTION_NAME) 

#quick commands - no clean
quick_build_lambda: build_lambda create_build_directory
	zip -r -j $(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) $(SWIFT_PROJECT_PATH)/.build/$(SWIFT_CONFIGURATION)/$(SWIFT_EXECUTABLE)

quick_deploy_lambda: quick_build_lambda create_build_directory
	aws lambda update-function-code --function-name $(LAMBDA_FUNCTION_NAME) --zip-file fileb://$(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) --profile $(AWS_PROFILE)

build_lambda_local: build_lambda
	if [ ! -d "$(LOCAL_LAMBDA_PATH)" ]; then mkdir -p $(LOCAL_LAMBDA_PATH); fi
	cp $(SWIFT_PROJECT_PATH)/.build/$(SWIFT_CONFIGURATION)/$(SWIFT_EXECUTABLE) $(LOCAL_LAMBDA_PATH)/.

invoke_lambda_local_once:
	$(eval LOCAL_LAMBDA_EVENT := '$(shell cat $(SWIFT_PROJECT_PATH)/event.json)')
	docker run --rm \
	-v "$(PWD)/$(LOCAL_LAMBDA_PATH)":/var/task:ro,delegated \
	-v "$(PWD)/bootstrap":/opt/bootstrap:ro,delegated \
	-v "$(PWD)/$(SHARED_LIBS_FOLDER)":/opt/swift-shared-libs:ro,delegated \
	lambci/lambda:provided $(LAMBDA_HANDLER) $(LOCAL_LAMBDA_EVENT)

start_lambda_local_env:
	docker run --rm \
	-e DOCKER_LAMBDA_STAY_OPEN=1 \
	-p 9001:9001 \
	-v "$(PWD)/$(LOCAL_LAMBDA_PATH)":/var/task:ro,delegated \
	-v "$(PWD)/bootstrap":/opt/bootstrap:ro,delegated \
	-v "$(PWD)/$(SHARED_LIBS_FOLDER)":/opt/swift-shared-libs:ro,delegated \
  	lambci/lambda:provided \
	$(LAMBDA_HANDLER)

invoke_lambda_local:
	aws lambda invoke --endpoint http://localhost:9001 --no-sign-request --function-name $(LAMBDA_FUNCTION_NAME) --payload "fileb://$(SWIFT_PROJECT_PATH)/event.json" $(TMP_BUILD_PATH)/outfile && echo "\nResult:" && cat $(TMP_BUILD_PATH)/outfile && echo "\n"

start_docker_compose_env:
	if [ ! -d "$(LOCALSTACK_TMP)" ]; then mkdir -p $(LOCALSTACK_TMP); fi
	make -f $(SWIFT_PROJECT_PATH)/Makefile start_docker_compose_env

stop_docker_compose_env:
	make -f $(SWIFT_PROJECT_PATH)/Makefile stop_docker_compose_env

test_lambda_local_output:
	cmp $(TMP_BUILD_PATH)/outfile $(SWIFT_PROJECT_PATH)/outfile.json