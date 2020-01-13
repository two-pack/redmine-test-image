# Docker image for testing Redmine

This Dockerfile creates Docker image for testing of [Redmine](https://www.redmine.org/).  
It's designed for [Redmine plugin test action](https://github.com/two-pack/redmine-plugin-test-action).

## Usage

### Arguments
* REDMINE_VERSION  
  Redmine version for testing, like **4.1.0**.  
* RUBY_VERSION  
  Ruby version for testing, like **ruby2.6**.

### Example
```shell
$ docker build --build-arg REDMINE_VERSION=4.1.0 --build-arg RUBY_VERSION=2.6 -f Dockerfile -t redmine-test-image .
```

## Hook for Dockerhub

[hooks\build](/hooks/build) is a hook script for Dockerhub Automated build.
It decides testing version of Redmine and Ruby by Dcoker Tag, like **4.1_ruby2.6**.

### Example of tag name
* 4.1.0_ruby2.6  
  Redmine 4.1.0 with Ruby 2.6
* trunk_ruby2.5  
  Redmine trunk with Ruby 2.5
* 4.1_ruby2.6  
  Redmine 4.1.x latest with Ruy 2.6

## License
This is released under the MIT license. See [LICENSE](/LICENSE) for more information.
