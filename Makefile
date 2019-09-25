
# Use this tag to build a customized local image

SWIFT_VERSION=5.1
LAYER_VERSION=5-1
# SWIFT_VERSION=5.0.3
# LAYER_VERSION=5-0-3
DOCKER_TAG=nio-swift:$(SWIFT_VERSION)
SWIFT_DOCKER_IMAGE=$(DOCKER_TAG)
SWIFT_LAMBDA_LIBRARY=nio-swift-lambda-runtime-$(LAYER_VERSION)
SWIFT_CONFIGURATION=release

# Configuration

# HelloWorld Example Configuration
# SWIFT_EXECUTABLE=HelloWorld
# SWIFT_PROJECT_PATH=Examples/HelloWorld
# LAMBDA_FUNCTION_NAME=HelloWorld
# LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).helloWorld

# HTTPSRequest Example Configuration
# SWIFT_EXECUTABLE=HTTPSRequest
# SWIFT_PROJECT_PATH=Examples/HTTPSRequest
# LAMBDA_FUNCTION_NAME=HTTPSRequest
# LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).getHttps

# S3Test Example Configuration
SWIFT_EXECUTABLE=S3Test
SWIFT_PROJECT_PATH=Examples/S3Test
LAMBDA_FUNCTION_NAME=S3Test
LAMBDA_HANDLER=$(SWIFT_EXECUTABLE).getObject

# Internals
LAMBDA_ZIP=lambda.zip
SHARED_LIBS_FOLDER=swift-shared-libs
LAYER_ZIP=swift-lambda-runtime-$(LAYER_VERSION).zip
LAMBDA_BUILD_PATH=.build
IAM_ROLE_NAME=lambda_sprinter_basic_execution

# use this for local development
MOUNT_ROOT=$(shell pwd)/..
DOCKER_PROJECT_PATH=aws-lambda-swift-sprinter/$(SWIFT_PROJECT_PATH)

# normal development
# MOUNT_ROOT=$(shell pwd)
# DOCKER_PROJECT_PATH=$(SWIFT_PROJECT_PATH)

# AWS Configuration
AWS_PROFILE=default
AWS_BUCKET=my-s3-bucket

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
	if [ ! -d "$(LAMBDA_BUILD_PATH)" ]; then mkdir $(LAMBDA_BUILD_PATH); fi;

package_lambda: clean_lambda create_build_directory build_lambda
	zip -r -j $(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) $(SWIFT_PROJECT_PATH)/.build/$(SWIFT_CONFIGURATION)/$(SWIFT_EXECUTABLE)

clean_layer:
	rm $(LAYER_ZIP) || true
	rm -r $(SHARED_LIBS_FOLDER) || true

package_layer_5_0: clean_layer create_build_directory
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
			cp -t $(SHARED_LIBS_FOLDER)/lib \
					/lib/x86_64-linux-gnu/libbsd.so.0 \
					/lib/x86_64-linux-gnu/libc.so.6 \
					/lib/x86_64-linux-gnu/libcom_err.so.2 \
					/lib/x86_64-linux-gnu/libcrypt.so.1 \
					/lib/x86_64-linux-gnu/libdl.so.2 \
					/lib/x86_64-linux-gnu/libgcc_s.so.1 \
					/lib/x86_64-linux-gnu/libkeyutils.so.1 \
					/lib/x86_64-linux-gnu/liblzma.so.5 \
					/lib/x86_64-linux-gnu/libm.so.6 \
					/lib/x86_64-linux-gnu/libpthread.so.0 \
					/lib/x86_64-linux-gnu/libresolv.so.2 \
					/lib/x86_64-linux-gnu/librt.so.1 \
					/lib/x86_64-linux-gnu/libutil.so.1 \
					/lib/x86_64-linux-gnu/libz.so.1 \
					/usr/lib/swift/linux/libBlocksRuntime.so \
					/usr/lib/swift/linux/libFoundation.so \
					/usr/lib/swift/linux/libdispatch.so \
					/usr/lib/swift/linux/libicudataswift.so.61 \
					/usr/lib/swift/linux/libicui18nswift.so.61 \
					/usr/lib/swift/linux/libicuucswift.so.61 \
					/usr/lib/swift/linux/libswiftCore.so \
					/usr/lib/swift/linux/libswiftDispatch.so \
					/usr/lib/swift/linux/libswiftGlibc.so \
					/usr/lib/swift/linux/libswiftSwiftOnoneSupport.so \
					/usr/lib/x86_64-linux-gnu/libasn1.so.8 \
					/usr/lib/x86_64-linux-gnu/libatomic.so.1 \
					/usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 \
					/usr/lib/x86_64-linux-gnu/libcurl.so.4 \
					/usr/lib/x86_64-linux-gnu/libffi.so.6 \
					/usr/lib/x86_64-linux-gnu/libgmp.so.10 \
					/usr/lib/x86_64-linux-gnu/libgnutls.so.30 \
					/usr/lib/x86_64-linux-gnu/libgssapi.so.3 \
					/usr/lib/x86_64-linux-gnu/libgssapi_krb5.so.2 \
					/usr/lib/x86_64-linux-gnu/libhcrypto.so.4 \
					/usr/lib/x86_64-linux-gnu/libheimbase.so.1 \
					/usr/lib/x86_64-linux-gnu/libheimntlm.so.0 \
					/usr/lib/x86_64-linux-gnu/libhogweed.so.4 \
					/usr/lib/x86_64-linux-gnu/libhx509.so.5 \
					/usr/lib/x86_64-linux-gnu/libicudata.so.60 \
					/usr/lib/x86_64-linux-gnu/libicuuc.so.60 \
					/usr/lib/x86_64-linux-gnu/libidn2.so.0 \
					/usr/lib/x86_64-linux-gnu/libk5crypto.so.3 \
					/usr/lib/x86_64-linux-gnu/libkrb5.so.26 \
					/usr/lib/x86_64-linux-gnu/libkrb5.so.3 \
					/usr/lib/x86_64-linux-gnu/libkrb5support.so.0 \
					/usr/lib/x86_64-linux-gnu/liblber-2.4.so.2 \
					/usr/lib/x86_64-linux-gnu/libldap_r-2.4.so.2 \
					/usr/lib/x86_64-linux-gnu/libnettle.so.6 \
					/usr/lib/x86_64-linux-gnu/libnghttp2.so.14 \
					/usr/lib/x86_64-linux-gnu/libp11-kit.so.0 \
					/usr/lib/x86_64-linux-gnu/libpsl.so.5 \
					/usr/lib/x86_64-linux-gnu/libroken.so.18 \
					/usr/lib/x86_64-linux-gnu/librtmp.so.1 \
					/usr/lib/x86_64-linux-gnu/libsasl2.so.2 \
					/usr/lib/x86_64-linux-gnu/libsqlite3.so.0 \
					/usr/lib/x86_64-linux-gnu/libssl.so.1.1 \
					/usr/lib/x86_64-linux-gnu/libstdc++.so.6 \
					/usr/lib/x86_64-linux-gnu/libtasn1.so.6 \
					/usr/lib/x86_64-linux-gnu/libunistring.so.2 \
					/usr/lib/x86_64-linux-gnu/libwind.so.0 \
					/usr/lib/x86_64-linux-gnu/libxml2.so.2
	zip -r $(LAMBDA_BUILD_PATH)/$(LAYER_ZIP) bootstrap $(SHARED_LIBS_FOLDER)

package_layer: clean_layer create_build_directory
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
			cp -t $(SHARED_LIBS_FOLDER)/lib \
					/lib/x86_64-linux-gnu/libbsd.so.0 \
					/lib/x86_64-linux-gnu/libc.so.6 \
					/lib/x86_64-linux-gnu/libcom_err.so.2 \
					/lib/x86_64-linux-gnu/libcrypt.so.1 \
					/lib/x86_64-linux-gnu/libdl.so.2 \
					/lib/x86_64-linux-gnu/libgcc_s.so.1 \
					/lib/x86_64-linux-gnu/libkeyutils.so.1 \
					/lib/x86_64-linux-gnu/liblzma.so.5 \
					/lib/x86_64-linux-gnu/libm.so.6 \
					/lib/x86_64-linux-gnu/libpthread.so.0 \
					/lib/x86_64-linux-gnu/libresolv.so.2 \
					/lib/x86_64-linux-gnu/librt.so.1 \
					/lib/x86_64-linux-gnu/libutil.so.1 \
					/lib/x86_64-linux-gnu/libz.so.1 \
					/usr/lib/swift/linux/libBlocksRuntime.so \
					/usr/lib/swift/linux/libFoundation.so \
					/usr/lib/swift/linux/libdispatch.so \
					/usr/lib/swift/linux/libicudataswift.so.61 \
					/usr/lib/swift/linux/libicui18nswift.so.61 \
					/usr/lib/swift/linux/libicuucswift.so.61 \
					/usr/lib/swift/linux/libswiftCore.so \
					/usr/lib/swift/linux/libswiftDispatch.so \
					/usr/lib/swift/linux/libswiftGlibc.so \
					/usr/lib/swift/linux/libswiftSwiftOnoneSupport.so \
					/usr/lib/swift/linux/libFoundationNetworking.so \
					/usr/lib/x86_64-linux-gnu/libasn1.so.8 \
					/usr/lib/x86_64-linux-gnu/libatomic.so.1 \
					/usr/lib/x86_64-linux-gnu/libcrypto.so.1.1 \
					/usr/lib/x86_64-linux-gnu/libcurl.so.4 \
					/usr/lib/x86_64-linux-gnu/libffi.so.6 \
					/usr/lib/x86_64-linux-gnu/libgmp.so.10 \
					/usr/lib/x86_64-linux-gnu/libgnutls.so.30 \
					/usr/lib/x86_64-linux-gnu/libgssapi.so.3 \
					/usr/lib/x86_64-linux-gnu/libgssapi_krb5.so.2 \
					/usr/lib/x86_64-linux-gnu/libhcrypto.so.4 \
					/usr/lib/x86_64-linux-gnu/libheimbase.so.1 \
					/usr/lib/x86_64-linux-gnu/libheimntlm.so.0 \
					/usr/lib/x86_64-linux-gnu/libhogweed.so.4 \
					/usr/lib/x86_64-linux-gnu/libhx509.so.5 \
					/usr/lib/x86_64-linux-gnu/libicudata.so.60 \
					/usr/lib/x86_64-linux-gnu/libicuuc.so.60 \
					/usr/lib/x86_64-linux-gnu/libidn2.so.0 \
					/usr/lib/x86_64-linux-gnu/libk5crypto.so.3 \
					/usr/lib/x86_64-linux-gnu/libkrb5.so.26 \
					/usr/lib/x86_64-linux-gnu/libkrb5.so.3 \
					/usr/lib/x86_64-linux-gnu/libkrb5support.so.0 \
					/usr/lib/x86_64-linux-gnu/liblber-2.4.so.2 \
					/usr/lib/x86_64-linux-gnu/libldap_r-2.4.so.2 \
					/usr/lib/x86_64-linux-gnu/libnettle.so.6 \
					/usr/lib/x86_64-linux-gnu/libnghttp2.so.14 \
					/usr/lib/x86_64-linux-gnu/libp11-kit.so.0 \
					/usr/lib/x86_64-linux-gnu/libpsl.so.5 \
					/usr/lib/x86_64-linux-gnu/libroken.so.18 \
					/usr/lib/x86_64-linux-gnu/librtmp.so.1 \
					/usr/lib/x86_64-linux-gnu/libsasl2.so.2 \
					/usr/lib/x86_64-linux-gnu/libsqlite3.so.0 \
					/usr/lib/x86_64-linux-gnu/libssl.so.1.1 \
					/usr/lib/x86_64-linux-gnu/libstdc++.so.6 \
					/usr/lib/x86_64-linux-gnu/libtasn1.so.6 \
					/usr/lib/x86_64-linux-gnu/libunistring.so.2 \
					/usr/lib/x86_64-linux-gnu/libwind.so.0 \
					/usr/lib/x86_64-linux-gnu/libxml2.so.2
	zip -r $(LAMBDA_BUILD_PATH)/$(LAYER_ZIP) bootstrap $(SHARED_LIBS_FOLDER)

upload_build_to_s3:
	aws s3 sync --acl public-read ./.build s3://$(AWS_BUCKET)/ --profile $(AWS_PROFILE)

upload_lambda_layer:
	aws lambda publish-layer-version --layer-name $(SWIFT_LAMBDA_LIBRARY) --description "AWS Custom Runtime Swift Shared Libraries with NIO" --zip-file fileb://$(LAMBDA_BUILD_PATH)/$(LAYER_ZIP) --output text --query LayerVersionArn --profile $(AWS_PROFILE) > $(LAMBDA_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt
	cat $(LAMBDA_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt

create_role:
	$(eval IAM_ROLE_ARN := $(shell aws iam list-roles --query "Roles[? RoleName == '$(IAM_ROLE_NAME)'].Arn" --profile $(AWS_PROFILE) --output text))
ifeq ($(IAM_ROLE_ARN),"")
	aws iam create-role --role-name $(IAM_ROLE_NAME) --description "Allows Lambda functions to call AWS services on your behalf." --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["sts:AssumeRole"],"Principal":{"Service":["lambda.amazonaws.com"]}}]}' --profile $(AWS_PROFILE)
	aws iam attach-role-policy --role-name $(IAM_ROLE_NAME) --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" --profile $(AWS_PROFILE)
    $(eval IAM_ROLE_ARN := $(shell aws iam list-roles --query "Roles[? RoleName == '$(IAM_ROLE_NAME)'].Arn" --output text --profile $(AWS_PROFILE)))
else
	$(info "The role $(IAM_ROLE_ARN) was already present")
endif

create_lambda: create_role
	$(eval LAMBDA_LAYER_ARN := $(shell cat $(LAMBDA_BUILD_PATH)/$(SWIFT_LAMBDA_LIBRARY)-arn.txt))
	$(info "$(LAMBDA_LAYER_ARN)")
	aws lambda create-function --function-name $(LAMBDA_FUNCTION_NAME) --runtime provided --handler $(LAMBDA_HANDLER) --role "$(IAM_ROLE_ARN)" --zip-file fileb://$(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) --layers $(LAMBDA_LAYER_ARN) --profile $(AWS_PROFILE)

update_lambda: package_lambda
	aws lambda update-function-code --function-name $(LAMBDA_FUNCTION_NAME) --zip-file fileb://$(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) --profile $(AWS_PROFILE)

invoke_lambda:
	aws lambda invoke --function-name $(LAMBDA_FUNCTION_NAME) --profile $(AWS_PROFILE) --payload "fileb://$(SWIFT_PROJECT_PATH)/event.json" $(LAMBDA_BUILD_PATH)/outfile && echo "\nResult:" && cat $(LAMBDA_BUILD_PATH)/outfile && echo "\n"

#quick commands - no clean
quick_build_lambda: build_lambda create_build_directory
	zip -r -j $(LAMBDA_BUILD_PATH)/$(LAMBDA_ZIP) $(SWIFT_PROJECT_PATH)/.build/$(SWIFT_CONFIGURATION)/$(SWIFT_EXECUTABLE)

quick_deploy_lambda: quick_build_lambda create_build_directory
	aws lambda update-function-code --function-name $(LAMBDA_FUNCTION_NAME) --zip-file fileb://$(LAMBDA_BUILD_PATH)/lambda.zip --profile $(AWS_PROFILE)