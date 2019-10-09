
# Use this tag to build a customized local image

SWIFT_VERSION?=5.1
LAYER_VERSION?=5-1
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

# Internals
LAMBDA_ZIP=lambda.zip
SHARED_LIBS_FOLDER=swift-shared-libs
LAYER_ZIP=swift-lambda-runtime-$(LAYER_VERSION).zip
LAMBDA_BUILD_PATH=./.build
IAM_ROLE_NAME=lambda_sprinter_basic_execution
DATETIME=$(shell date +'%y%m%d-%H%M%S')
AWS_LAYER_BUCKET=aws-lambda-swift-sprinter-layers

# use this for local development
MOUNT_ROOT=$(shell pwd)/..
DOCKER_PROJECT_PATH=aws-lambda-swift-sprinter/$(SWIFT_PROJECT_PATH)

# normal development
# MOUNT_ROOT=$(shell pwd)
# DOCKER_PROJECT_PATH=$(SWIFT_PROJECT_PATH)

# AWS Configuration
AWS_PROFILE?=default
AWS_BUCKET?=aws-lambda-swift-sprinter

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
	if [ ! -d "$(LAMBDA_BUILD_PATH)" ]; then mkdir $(LAMBDA_BUILD_PATH); fi

package_lambda: clean_lambda create_build_directory build_lambda
	zip -r -j $(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) $(SWIFT_PROJECT_PATH)/.build/$(SWIFT_CONFIGURATION)/$(SWIFT_EXECUTABLE)

clean_layer:
	rm $(LAMBDA_BUILD_PATH)/$(LAYER_ZIP) || true
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
	zip -r $(LAMBDA_BUILD_PATH)/$(LAYER_ZIP) bootstrap $(SHARED_LIBS_FOLDER)

upload_build_to_s3: create_lambda_s3_key
	aws s3 cp --acl public-read "$(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP)" s3://$(AWS_BUCKET)/$(LAMBDA_S3_UPLOAD_PATH)/$(LAMBDA_ZIP) --profile $(AWS_PROFILE)

create_layer_s3_key:
	$(eval LAYER_S3_UPLOAD_PATH := $(SWIFT_LAMBDA_LIBRARY)/$(DATETIME))

upload_lambda_layer_with_s3: create_layer_s3_key
	aws s3 cp --acl public-read "$(LAMBDA_BUILD_PATH)/$(LAYER_ZIP)" s3://$(AWS_LAYER_BUCKET)/$(LAYER_S3_UPLOAD_PATH)/$(LAYER_ZIP) --profile $(AWS_PROFILE)
	aws lambda publish-layer-version --layer-name $(SWIFT_LAMBDA_LIBRARY) --description "AWS Custom Runtime Swift Shared Libraries with NIO" --content "S3Bucket=$(AWS_LAYER_BUCKET),S3Key=$(LAYER_S3_UPLOAD_PATH)/$(LAYER_ZIP)" --output text --query LayerVersionArn --profile $(AWS_PROFILE) > $(LAMBDA_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt
	cat $(LAMBDA_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt

upload_lambda_layer:
	aws lambda publish-layer-version --layer-name $(SWIFT_LAMBDA_LIBRARY) --description "AWS Custom Runtime Swift Shared Libraries with NIO" --zip-file fileb://$(LAMBDA_BUILD_PATH)/$(LAYER_ZIP) --output text --query LayerVersionArn --profile $(AWS_PROFILE) > $(LAMBDA_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt
	cat $(LAMBDA_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt

create_role:
	aws iam create-role --role-name $(IAM_ROLE_NAME) --description "Allows Lambda functions to call AWS services on your behalf." --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["sts:AssumeRole"],"Principal":{"Service":["lambda.amazonaws.com"]}}]}' --profile $(AWS_PROFILE) || true
	aws iam attach-role-policy --role-name $(IAM_ROLE_NAME) --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" --profile $(AWS_PROFILE) || true
    $(eval IAM_ROLE_ARN := $(shell aws iam list-roles --query "Roles[? RoleName == '$(IAM_ROLE_NAME)'].Arn" --output text --profile $(AWS_PROFILE)))

create_lambda: create_role package_lambda
	$(eval LAMBDA_LAYER_ARN := $(shell cat $(LAMBDA_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt))
	$(info "$(LAMBDA_LAYER_ARN)")
	aws lambda create-function --function-name $(LAMBDA_FUNCTION_NAME) --runtime provided --handler $(LAMBDA_HANDLER) --role "$(IAM_ROLE_ARN)" --zip-file fileb://$(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) --layers $(LAMBDA_LAYER_ARN) --profile $(AWS_PROFILE)

create_lambda_s3_key:
	$(eval LAMBDA_S3_UPLOAD_PATH := $(LAMBDA_FUNCTION_NAME)/$(DATETIME))

create_lambda_with_s3: create_role package_lambda upload_build_to_s3
	$(eval LAMBDA_LAYER_ARN := $(shell cat $(LAMBDA_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt))
	$(info "$(LAMBDA_LAYER_ARN)")
	aws lambda create-function --function-name $(LAMBDA_FUNCTION_NAME) --runtime provided --handler $(LAMBDA_HANDLER) --role "$(IAM_ROLE_ARN)" --code "S3Bucket=$(AWS_BUCKET),S3Key=$(LAMBDA_S3_UPLOAD_PATH)/$(LAMBDA_ZIP)" --layers $(LAMBDA_LAYER_ARN) --profile $(AWS_PROFILE)

update_lambda: package_lambda
	aws lambda update-function-code --function-name $(LAMBDA_FUNCTION_NAME) --zip-file fileb://$(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) --profile $(AWS_PROFILE)

update_lambda_with_s3: package_lambda upload_build_to_s3
	aws lambda update-function-code --function-name $(LAMBDA_FUNCTION_NAME) --s3-bucket $(AWS_BUCKET) --s3-key "$(LAMBDA_S3_UPLOAD_PATH)/$(LAMBDA_ZIP)" --profile $(AWS_PROFILE)

invoke_lambda:
	aws lambda invoke --function-name $(LAMBDA_FUNCTION_NAME) --profile $(AWS_PROFILE) --payload "fileb://$(SWIFT_PROJECT_PATH)/event.json" $(LAMBDA_BUILD_PATH)/outfile && echo "\nResult:" && cat $(LAMBDA_BUILD_PATH)/outfile && echo "\n"

#quick commands - no clean
quick_build_lambda: build_lambda create_build_directory
	zip -r -j $(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) $(SWIFT_PROJECT_PATH)/.build/$(SWIFT_CONFIGURATION)/$(SWIFT_EXECUTABLE)

quick_deploy_lambda: quick_build_lambda create_build_directory
	aws lambda update-function-code --function-name $(LAMBDA_FUNCTION_NAME) --zip-file fileb://$(LAMBDA_BUILD_PATH)/lambda.zip --profile $(AWS_PROFILE)