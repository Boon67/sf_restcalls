"""
Setup script for the Snowflake REST Calls library.
"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

with open("requirements.txt", "r", encoding="utf-8") as fh:
    requirements = [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="sf-restcalls",
    version="1.0.0",
    author="Your Name",
    author_email="your.email@example.com",
    description="A Python library for connecting to Snowflake using PAT tokens and executing stored procedures",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/sf-restcalls",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
    python_requires=">=3.8",
    install_requires=requirements,
    entry_points={
        "console_scripts": [
            "sf-restcalls=sf_restcalls.cli:main",
        ],
    },
    include_package_data=True,
    zip_safe=False,
)
