from fastapi import APIRouter

router = APIRouter()


@router.api_route('/acl/create-user')
async def create_user():
     return {'message': 'User create successfully'}
