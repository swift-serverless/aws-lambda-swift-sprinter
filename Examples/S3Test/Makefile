# Note: This must be launched from the root path
SWIFT_PROJECT_PATH=Examples/S3Test

start_docker_compose_env:
	cd $(SWIFT_PROJECT_PATH); docker-compose up -d ; sleep 5
	aws --endpoint http://localhost:4572 s3 mb s3://my-s3-bucket
	aws --endpoint http://localhost:4572 s3 cp $(SWIFT_PROJECT_PATH)/hello.txt s3://my-s3-bucket/hello.txt

stop_docker_compose_env:
	cd $(SWIFT_PROJECT_PATH); docker-compose stop