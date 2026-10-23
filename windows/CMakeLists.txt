# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(lawyers_e_diary LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "lawyers_e_diary")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# === MSIX Packaging Target ===
# Creates an MSIX package for Microsoft Store distribution.
# Usage: cmake --build <build_dir> --target msix_package
# Requires: MakeAppx.exe and SignTool.exe (Windows SDK)
#
# Tool discovery is deferred to when the msix_package target is actually
# invoked, so that ordinary Flutter Debug/Profile/Release builds do not fail
# when the Windows SDK tools are not on PATH.
#
# The Windows SDK is typically installed under:
#   C:\Program Files (x86)\Windows Kits\10\bin\<version>\<arch>\
# We search the latest installed SDK version and prefer x64 tools.

# Helper function to discover Windows SDK tools without hard-failing.
function(find_windows_sdk_tool TOOL_NAME OUT_VAR)
  # First try PATH
  find_program(${OUT_VAR} NAMES ${TOOL_NAME}.exe)
  if(${OUT_VAR})
    return()
  endif()

  # Search common Windows SDK install locations
  set(SDK_ROOT "C:/Program Files (x86)/Windows Kits/10/bin")
  if(EXISTS "${SDK_ROOT}")
    # Find the latest SDK version directory
    file(GLOB SDK_VERSIONS "${SDK_ROOT}/*")
    if(SDK_VERSIONS)
      list(SORT SDK_VERSIONS)
      list(REVERSE SDK_VERSIONS)
      foreach(VERSION_DIR ${SDK_VERSIONS})
        if(IS_DIRECTORY "${VERSION_DIR}")
          # Prefer x64, then x86, then arm64
          foreach(ARCH x64 x86 arm64)
            if(EXISTS "${VERSION_DIR}/${ARCH}/${TOOL_NAME}.exe")
              set(${OUT_VAR} "${VERSION_DIR}/${ARCH}/${TOOL_NAME}.exe" PARENT_SCOPE)
              return()
            endif()
          endforeach()
        endif()
      endforeach()
    endif()
  endif()

  # Not found — set to empty
  set(${OUT_VAR} "" PARENT_SCOPE)
endfunction()

find_windows_sdk_tool(makeappx MAKEAPPX_EXE)
find_windows_sdk_tool(signtool SIGNTOOL_EXE)

# Only define the msix_package target if MakeAppx is available.
# If not available, provide a stub that prints a clear error message.
if(MAKEAPPX_EXE)
  set(MSIX_OUTPUT_NAME "${BINARY_NAME}.msix")
  set(MSIX_OUTPUT_PATH "${CMAKE_BINARY_DIR}/${MSIX_OUTPUT_NAME}")
  set(MSIX_TEMP_DIR "${CMAKE_BINARY_DIR}/msix_temp")

  add_custom_target(msix_package
    COMMAND ${CMAKE_COMMAND} -E remove_directory ${MSIX_TEMP_DIR}
    COMMAND ${CMAKE_COMMAND} -E make_directory ${MSIX_TEMP_DIR}
    # Copy build artifacts
    COMMAND ${CMAKE_COMMAND} -E copy_directory
      "$<TARGET_FILE_DIR:${BINARY_NAME}>" ${MSIX_TEMP_DIR}
    # Copy AppxManifest.xml
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
      "${CMAKE_CURRENT_SOURCE_DIR}/runner/AppxManifest.xml"
      ${MSIX_TEMP_DIR}/AppxManifest.xml
    # Copy icon assets
    COMMAND ${CMAKE_COMMAND} -E copy_directory
      "${CMAKE_CURRENT_SOURCE_DIR}/runner/assets/icons"
      ${MSIX_TEMP_DIR}/assets/icons
    # Create MSIX package
    COMMAND "${MAKEAPPX_EXE}" pack /h SHA256 /d ${MSIX_TEMP_DIR} /p ${MSIX_OUTPUT_PATH}
    COMMAND ${CMAKE_COMMAND} -E echo "MSIX package created: ${MSIX_OUTPUT_PATH}"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Building MSIX package..."
  )

  # Optional signing target
  if(SIGNTOOL_EXE)
    add_custom_target(msix_sign
      DEPENDS msix_package
      COMMAND "${SIGNTOOL_EXE}" sign /a /v /f "${CMAKE_CURRENT_SOURCE_DIR}/runner/resources/lawyers-e-diary.pfx"
        /t http://timestamp.digicert.com ${MSIX_OUTPUT_PATH}
      COMMAND "${SIGNTOOL_EXE}" verify /a /v ${MSIX_OUTPUT_PATH}
      WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
      COMMENT "Signing MSIX package..."
    )
  else()
    add_custom_target(msix_sign
      COMMAND ${CMAKE_COMMAND} -E echo "ERROR: SignTool.exe not found. Install Windows SDK to sign MSIX packages."
      COMMENT "Signing MSIX package (SignTool not available)..."
    )
  endif()
else()
  # Stub targets that fail with a clear, actionable message
  add_custom_target(msix_package
    COMMAND ${CMAKE_COMMAND} -E echo "ERROR: MakeAppx.exe not found. Install the Windows SDK (https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/) and ensure it is available in PATH or at C:/Program Files (x86)/Windows Kits/10/bin/."
    COMMENT "MSIX packaging (MakeAppx not available)..."
  )
  add_custom_target(msix_sign
    DEPENDS msix_package
    COMMAND ${CMAKE_COMMAND} -E echo "ERROR: MakeAppx.exe not found. Cannot sign without a package."
    COMMENT "MSIX signing (MakeAppx not available)..."
  )
endif()
