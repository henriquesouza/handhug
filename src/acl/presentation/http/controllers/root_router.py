from fastapi import APIRouter

from acl.presentation.http.controllers.create_user import router

api_router = APIRouter()

api_router.include_router(router)