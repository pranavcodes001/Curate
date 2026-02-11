from fastapi import APIRouter
from app.api.v1.endpoints import stories, summaries, auth, admin, comments, saved_threads, search, interests, feed

router = APIRouter()
router.include_router(stories.router, prefix="/stories")
# summaries router registers path /stories/{hn_id}/summary
router.include_router(summaries.router)
router.include_router(auth.router)
router.include_router(admin.router)
router.include_router(comments.router)
router.include_router(saved_threads.router)
router.include_router(search.router)
router.include_router(interests.router)
router.include_router(feed.router)
