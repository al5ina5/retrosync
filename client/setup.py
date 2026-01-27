from setuptools import setup, find_packages

setup(
    name="retrosync",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "boto3>=1.34.0",
        "requests>=2.31.0",
        "watchdog>=3.0.0",
        "pyyaml>=6.0.1",
    ],
    entry_points={
        "console_scripts": [
            "retrosync=retrosync.daemon:main",
        ],
    },
    python_requires=">=3.9",
)
