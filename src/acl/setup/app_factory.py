from fastapi import FastAPI

from acl.presentation.http.controllers import root_router


def create_app() -> FastAPI:
    app = FastAPI()

    app.include_router(router=root_router.api_router)

    return app