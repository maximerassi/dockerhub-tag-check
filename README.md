# DockerHub Tag Checker
Check DockerHub if the specified tag exists for a particular image (in your private repo).

## Usage
```
./dockerhub-tag-check.sh -u username -p password -i myimage -t ec98d823132
> FOUND

./dockerhub-tag-check.sh -u username -p password -i myimage -t 123
> NOT_FOUND
```

## Note
Please note: This script is meant to be used within a CI pipeline. In such pipelines, sensitive information such as a password can be automatically hidden from all logs when it is stored as a secret environment variable. Please ensure your password does not end up in clear text in any logs by referring to your pipeline's documentation.
