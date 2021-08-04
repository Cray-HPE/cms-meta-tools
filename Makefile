# Copyright 2019-2021 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
# (MIT License)

# If you wish to perform a local build, you will need to clone or copy the contents of the
# cms-meta-tools repo to ./cms_meta_tools

CHART_PATH ?= charts

IMPORT_CONFIG_CHART_NAME ?= "cray-import-config"
IMPORT_KIWI_RECIPE_IMAGE_CHART_NAME ?= "cray-import-kiwi-recipe-image"

IMPORT_CONFIG_CHART_VERSION ?= local
IMPORT_KIWI_RECIPE_IMAGE_CHART_VERSION ?= local

HELM_UNITTEST_IMAGE ?= quintush/helm-unittest:3.3.0-0.2.5

all: runbuildprep lint chart_setup test package

test: import_config_test import_kiwi_recipe_image_test
package: import_config_package import_kiwi_recipe_image_package

runbuildprep:
		./cms_meta_tools/scripts/runBuildPrep.sh

lint:
		./cms_meta_tools/scripts/runLint.sh

chart_setup:
		mkdir -p ${CHART_PATH}/.packaged

import_config_test:
		helm lint "${CHART_PATH}/${IMPORT_CONFIG_CHART_NAME}"
		docker run --rm -v ${PWD}/${CHART_PATH}:/apps ${HELM_UNITTEST_IMAGE} -3 ${IMPORT_CONFIG_CHART_NAME}

import_kiwi_recipe_image_test:
		helm lint "${CHART_PATH}/${IMPORT_KIWI_RECIPE_IMAGE_CHART_NAME}"
		docker run --rm -v ${PWD}/${CHART_PATH}:/apps ${HELM_UNITTEST_IMAGE} -3 ${IMPORT_KIWI_RECIPE_IMAGE_CHART_NAME}

import_config_package:
		helm dep up ${CHART_PATH}/${IMPORT_CONFIG_CHART_NAME}
		helm package ${CHART_PATH}/${IMPORT_CONFIG_CHART_NAME} -d ${CHART_PATH}/.packaged --version ${IMPORT_CONFIG_CHART_VERSION}

import_kiwi_recipe_image_package:
		helm dep up ${CHART_PATH}/${IMPORT_KIWI_RECIPE_IMAGE_CHART_NAME}
		helm package ${CHART_PATH}/${IMPORT_KIWI_RECIPE_IMAGE_CHART_NAME} -d ${CHART_PATH}/.packaged --version ${IMPORT_KIWI_RECIPE_IMAGE_CHART_VERSION}
