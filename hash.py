# This script calculates a cache key for all the dependencies and their versions
# It recursively processes CMakeLists.txt and the included files, plus the submodules

import os
import sys
import hashlib
import subprocess
import shlex

def hash_file(path):
    with open(path, "rb") as f:
        digest = hashlib.sha1(f.read())
        return digest.hexdigest()

def git(command):
    args = ["git"] + shlex.split(command)
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        raise Exception(f"git {command} failed with exit code {result.returncode}")
    return result.stdout.decode("utf-8").rstrip()

def process_includes(cmake_dir, cmake_path):
    status = [f"{hash_file(cmake_path)} {os.path.basename(cmake_path)}"]
    with open(cmake_path, "r") as f:
        for line in f.readlines():
            line = line.strip()
            if line.startswith("include("):
                include_file = line[8:-1]
                include_path = os.path.join(cmake_dir, include_file)
                if os.path.exists(include_path):
                    status += process_includes(cmake_dir, include_path)
    return status

def main():
    debug = len(sys.argv) > 1

    # Process CMakeLists.txt and includes
    cmake_dir = os.path.dirname(__file__)
    os.chdir(cmake_dir)
    cmake_path = os.path.join(cmake_dir, "CMakeLists.txt")
    cmake_status = process_includes(cmake_dir, cmake_path)

    # Process submodules
    submodule_status = []
    for dir in sorted(os.listdir(cmake_dir)):
        if os.path.isdir(dir):
            try:
                hash = git(f"submodule status \"{os.path.abspath(dir)}\"").strip().split(" ")[0]
                submodule_status.append(f"{hash} {os.path.basename(dir)}")
            except:
                pass

    # Calculate the final hash
    final_status = str.join("\n", cmake_status)
    final_status += "\n"
    final_status += str.join("\n", submodule_status)
    final_hash = hashlib.sha1(final_status.encode("utf-8")).hexdigest()
    sys.stdout.write(final_hash + "\n")
    sys.stdout.flush()

    # Additional debug output to stderr
    if debug:
        sys.stderr.write(final_status + "\n")
        sys.stderr.write(final_hash + "\n")
        sys.stderr.flush()

if __name__ == "__main__":
    main()
