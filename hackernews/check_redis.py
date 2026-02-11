import asyncio
import json
from app.services.cache.redis import RedisCache
from app.config import settings

async def check_redis():
    redis = RedisCache(url=settings.REDIS_URL)
    await redis.init()
    
    if not redis.enabled():
        print("Redis not enabled")
        return
        
    print("--- Interest Queue ---")
    qlen = await redis.llen("interest_fetch_queue")
    print(f"Queue length: {qlen}")
    
    print("\n--- Watermarks ---")
    val = await redis._client.hgetall("interest_watermarks")
    print(val)
    
    print("\n--- Summary Queue ---")
    slen = await redis.llen("summary_queue")
    print(f"Summary Queue length: {slen}")
    
    await redis.close()

if __name__ == "__main__":
    asyncio.run(check_redis())
