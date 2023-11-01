####################################################################################################################
# Setup containers to run Airflow

# Runs docker compose commands to start services defined in a docker-compose.yml file.
# --env-file env: Specifies an environment file.
# up airflow-init: Initializes the airflow service.
# up --build -d: Builds and starts the services in detached mode.

# The command make up must be executed first, as it create container `webserver`, the prerequisite of many following `docker exec webserver` cmds
# The 2nd docker compose doesn't specify service，it will spin up all `services` in docker-compose.yml, including airflow-server
# based on docker-compose.yml, airflow's webserver and scheduler will be in different container 

docker-spin-up:
	docker compose --env-file env up airflow-init && docker compose --env-file env up --build -d

# Create 6 folders (logs...migrations), -p can make sure no error if already exist
# Sets permissions for the created directories, allowing all users read, write, and execute permissions
perms:
	sudo mkdir -p logs plugins temp dags tests migrations && sudo chmod -R u=rwx,g=rwx,o=rwx logs plugins temp dags tests migrations


# Start Docker Containers

# execute 3 sub cmds in sequence
up: perms docker-spin-up warehouse-migration

down:
	docker compose down

sh:
	docker exec -ti webserver bash

####################################################################################################################
# Testing, auto formatting, type checks, & Lint checks
# isort: a Python library to sort `imports` alphabetically
# flake8: check code syntax and provide instructions on how to clean it
# 		  where will it be installed: All services that use `x-airflow-common` configuration
#		  where will it be executed: only in the webserver container

pytest:
	docker exec webserver pytest -p no:warnings -v /opt/airflow/tests

format:
	docker exec webserver python -m black -S --line-length 79 .

isort:
	docker exec webserver isort .

type:
	docker exec webserver mypy --ignore-missing-imports /opt/airflow

lint: 
	docker exec webserver flake8 /opt/airflow/dags

ci: isort format type lint pytest

####################################################################################################################
# Set up cloud infrastructure

tf-init:
	terraform -chdir=./terraform init

# terraform will combine all .tf files in that folder (most important: maint.tf) and set up infra
# For example, `terraform apply`:
# 1) it will create private key based on main.tf
# 2) create EC2 instance, install docker, docker-compose, and copy current git repo to EC2

infra-up:
	terraform -chdir=./terraform apply

# after `terraform destroy`, output won't work as state file has been destroyed
infra-config:
	terraform -chdir=./terraform output

infra-down:
	terraform -chdir=./terraform destroy


####################################################################################################################
# Create tables in Warehouse

# 1) first of all, you will need to enter the name
# 2) Docker will execute the command `yoyo new ./migrations -m "$$migration_name"` in the `webserver` container (already create in `make up`)
# 3) use `yoyo-migrations` library to create a new migration file and saved in ./migrations folder,
# the filename is based on the current date, time, and the migration name provided by the user.
db-migration:
	@read -p "Enter migration name:" migration_name; docker exec webserver yoyo new ./migrations -m "$$migration_name"


# inside docker container `webserver`, yoyo develop (apply part) will refer ./migrations content to update existing database `finance`
# the database is located in `warehouse` container, as defined in docker-compose.yml
warehouse-migration:
	docker exec webserver yoyo develop --no-config-file --database postgres://sdeuser:sdepassword1234@warehouse:5432/finance ./migrations

# inside docker container `webserver`, executing yoyo rollback (rollback part)
warehouse-rollback:
	docker exec webserver yoyo rollback --no-config-file --database postgres://sdeuser:sdepassword1234@warehouse:5432/finance ./migrations

####################################################################################################################
# Port forwarding to local machine (Metabase and Airflow is running in EC2, but you can access them in your machine without actually run them)

# After executing `terraform apply`, terraform generated private key, aws ec2 instance's public dns... all saved in tfstate file
# we can see its value in the output or use `output -raw private_key` to get that key 


# After port forwarding, you can access the EC2's 3000 port using http://localhost:3001

# ssh: Initiates an SSH connection.
# -o "IdentitiesOnly yes": Ensures that only the identity file provided with the -i flag is used for authentication.
# -i private_key.pem: Specifies the private key file to use for authentication.
# ubuntu@$(terraform -chdir=./terraform output -raw ec2_public_dns): SSH as the ubuntu user to the EC2 instance whose public DNS is retrieved from Terraform's output.
# -N: Tells SSH to not execute any commands on the remote server, useful when just forwarding ports.
# -f: Puts SSH in the background once the authentication is successful.
# -L 3001:$(terraform -chdir=./terraform output -raw ec2_public_dns):3000: Sets up local port forwarding from local port 3001 to port 3000 on the EC2 instance.
cloud-metabase:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && chmod 600 private_key.pem && ssh -o "IdentitiesOnly yes" -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) -N -f -L 3001:$$(terraform -chdir=./terraform output -raw ec2_public_dns):3000 && open http://localhost:3001 && rm private_key.pem

# you can access the EC2's 8080 port using http://localhost:8081 on your local machine's browser
cloud-airflow:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && chmod 600 private_key.pem && ssh -o "IdentitiesOnly yes" -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) -N -f -L 8081:$$(terraform -chdir=./terraform output -raw ec2_public_dns):8080 && open http://localhost:8081 && rm private_key.pem

####################################################################################################################
# Helpers
# SSH into the EC2 instance
ssh-ec2:
	terraform -chdir=./terraform output -raw private_key > private_key.pem && chmod 600 private_key.pem && ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i private_key.pem ubuntu@$$(terraform -chdir=./terraform output -raw ec2_public_dns) && rm private_key.pem
