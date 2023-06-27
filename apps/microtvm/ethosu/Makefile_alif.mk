# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.


.PHONY: clean

CC := arm-none-eabi-gcc
CXX := arm-none-eabi-g++
AR := arm-none-eabi-ar
OBJCOPY := arm-none-eabi-objcopy

PWD := $(abspath $(shell pwd))
BUILD_DIR := $(PWD)/build
PLATFORM ?= RTSS_HP

ALIF_ML_KIT_PATH ?= $(BUILD_DIR)/dependencies/alif_ml-embedded-evaluation-kit
ALIF_CMSIS_PATH ?= $(BUILD_DIR)/dependencies/alif_ensemble-cmsis-dfp
ETHOSU_DRIVER_PATH ?= /opt/arm/ethosu/core_driver
ETHOSU_PLATFORM_PATH ?= /opt/arm/ethosu/core_platform

ifeq ($(PLATFORM), RTSS_HP)
CORE_TYPE = M55_HP
LINKER_SCRIPT = $(PWD)/gcc_M55_HP.ld
else ifeq ($(PLATFORM), RTSS_HE)
CORE_TYPE = M55_HE
LINKER_SCRIPT = $(PWD)/gcc_M55_HE.ld
else
$(error Platform $(PLATFORM) not specified or unknown)
endif


STANDALONE_CRT_PATH := $(BUILD_DIR)/runtime
CODEGEN_PATH := $(BUILD_DIR)/codegen/host

CCFLAGS := \
	-mcpu=cortex-m55 -mthumb -mfloat-abi=hard -mlittle-endian \
	-std=gnu99 -O3 \
	-Wall -Wno-unused-parameter \
	-DPRIu64=\"llu\" \
	-DLOG_LEVEL=LOG_LEVEL_WARN \
	-D$(CORE_TYPE) \
	-DCONSOLE_UART=4 \
	-DARM_NPU \
	-DETHOS_U_SEC_ENABLED=1 \
	-DETHOS_U_PRIV_ENABLED=1 \
	-DETHOS_U_BASE_ADDR=0x400E1000 \
	-DETHOS_U_IRQN=55

LDFLAGS := -lm -specs=nosys.specs \
	-Wl,-Map=$(BUILD_DIR)/demo_alif.map,--cref \
	-T $(LINKER_SCRIPT)

INCLUDES := \
	-I${PWD}/include \
	-I${CMSIS_PATH}/CMSIS/Core/Include \
	-I${BUILD_DIR}/crt_config \
	-I${ETHOSU_DRIVER_PATH}/include \
	-I${STANDALONE_CRT_PATH}/include \
	-I${STANDALONE_CRT_PATH}/src/runtime/crt/include \
	-I$(CODEGEN_PATH)/include \
	-I$(ALIF_ML_KIT_PATH)/source/log/include \
	-I$(ALIF_ML_KIT_PATH)/source/hal/source/components/npu/include \
	-I$(ALIF_ML_KIT_PATH)/source/hal/source/components/platform_pmu/include \
	-I$(ALIF_ML_KIT_PATH)/source/hal/source/platform/ensemble/include \
	-I$(ALIF_ML_KIT_PATH)/source/hal/source/platform/ensemble/services_lib/include \
	-I$(ALIF_ML_KIT_PATH)/source/hal/source/platform/ensemble/services_lib/drivers/include \
	-I$(ALIF_CMSIS_PATH)/Alif_CMSIS/Include \
	-I$(ALIF_CMSIS_PATH)/Device/$(CORE_TYPE) \
	-I$(ALIF_CMSIS_PATH)/Device/$(CORE_TYPE)/Include \
	-I$(ALIF_CMSIS_PATH)/Device/$(CORE_TYPE)/Config

SRCS := \
	src/demo_bare_metal_alif.c \
	src/tvm_ethosu_runtime.c \
	$(wildcard $(CODEGEN_PATH)/src/*.c) \
	$(STANDALONE_CRT_PATH)/src/runtime/crt/memory/stack_allocator.c \
	$(STANDALONE_CRT_PATH)/src/runtime/crt/common/crt_backend_api.c \
	$(wildcard $(ALIF_ML_KIT_PATH)/source/hal/source/components/npu/*.c) \
	$(wildcard $(ALIF_ML_KIT_PATH)/source/hal/source/platform/ensemble/source/*.c) \
	$(wildcard $(ALIF_ML_KIT_PATH)/source/hal/source/platform/ensemble/services_lib/drivers/src/*.c) \
	$(wildcard $(ALIF_ML_KIT_PATH)/source/hal/source/platform/ensemble/services_lib/services_lib/*.c) \
	$(wildcard $(ALIF_CMSIS_PATH)/Device/$(CORE_TYPE)/Source/*.c) \
	$(ALIF_CMSIS_PATH)/Alif_CMSIS/Source/Driver_PINMUX_AND_PINPAD.c \
	$(ALIF_CMSIS_PATH)/Alif_CMSIS/Source/Driver_USART.c \
	$(ALIF_CMSIS_PATH)/Alif_CMSIS/Source/Driver_GPIO.c \
	$(ALIF_CMSIS_PATH)/Alif_CMSIS/Source/GPIO_ll_drv.c


demo_alif: $(BUILD_DIR)/demo_alif

${BUILD_DIR}/libethosu_core_driver/libethosu_core_driver.a: $(ETHOSU_DRIVER_PATH)
	mkdir -p $(BUILD_DIR)/libethosu_core_driver
	cd $(BUILD_DIR)/libethosu_core_driver && \
		cmake -S $(ETHOSU_DRIVER_PATH) \
		-DCMAKE_TOOLCHAIN_FILE=${ETHOSU_PLATFORM_PATH}/cmake/toolchain/arm-none-eabi-gcc.cmake \
		-DETHOSU_LOG_SEVERITY=warning \
		-DTARGET_CPU=cortex-m55 \
		-DCMAKE_BUILD_TYPE=Release && \
		make

$(BUILD_DIR)/demo_alif: $(SRCS) ${BUILD_DIR}/libethosu_core_driver/libethosu_core_driver.a
	mkdir -p $(@D)
	$(CC) $(CCFLAGS) $(INCLUDES) $^ -o $@ $(LDFLAGS)
	$(OBJCOPY) -O binary $@ $@.bin
	truncate --size=%16 $@.bin

cleanall:
	rm -rf $(BUILD_DIR)

.DEFAULT: demo_alif
