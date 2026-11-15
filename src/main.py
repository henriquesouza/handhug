# TODO: the microservice to be run should be defined in environment variables

from acl.setup import app_factory

app = app_factory.create_app()
