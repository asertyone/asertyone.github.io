#!/bin/bash
#
sudo docker start gtest_server
# root
sudo docker exec -u 0 -w /docker_vol -it gtest_server bash
