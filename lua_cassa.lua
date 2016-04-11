
function string.fromhex(str)
	local x = {}
    for y in str:gmatch('(..)') do
        x[#x+1] = string.char( tonumber(y, 16) )
        print( string.char( tonumber(y, 16) ) )
    end
    return table.concat( x )
end



ngx.header.content_type = "text/plain" 

local imageId = ngx.var.uri:match( "cimage/([^/]+)/?$" );


	
if not imageId then 
	ngx.log(ngx.ERR, "image id is not present ", err) 
	ngx.status = 400
	ngx.say("invalid request");
	do return end
end 
	
	
local cookie = ngx.var.cookie_PHPSESSID;
--cookie = "52djtis6mk3vgbc0qjcdbnipa5"
if not cookie then
	ngx.status = 500
	ngx.say("Authentication failed");
	do return end
end


local memcached = require "resty.memcached" 
local memc = memcached:new() 

memc:set_timeout(1000) -- 1000 ms 

local ok, err = memc:connect("127.0.0.1",11211) 
if not ok then 
	ngx.log(ngx.ERR, "failed to connect memcache ", err) 
	ngx.status = 500
	ngx.say("Internal server error");
	do return end
end 

local res, flags, err = memc:get("memc.sess.key." .. cookie) 
if err then 
	ngx.log(ngx.ERR, "failed to get key: ", err) 
	ngx.status = 500
	ngx.say("Internal server error");
	do return end
end 

if not res then 
	ngx.log(ngx.ERR, "key not found in memcache " .. cookie) 
	ngx.status = 500
	ngx.say("Internal server error");
	do return end
else 
	st, en, orgId, cap2, cap3 = string.find(res,"s:5:\"orgid\";s:%d:\"(%d+)\"");
	if not orgId then 
		ngx.log(ngx.INFO, "No Org id");
		ngx.status = 500
		ngx.say("Internal server error");
		do return end
	end
end 


local ok, err = memc:set_keepalive(0, 800) 
if not ok then 
	ngx.log(ngx.ERR, "failed to set keepalive: ", err) 
end 



local cassandra = require "cassandra"
local session = cassandra.new()
session:set_timeout(1000)
local connected, err = session:connect("192.168.8.62", 9042)
session:set_keyspace("keyspace_images")
local imageContentArr, err = session:execute("SELECT * from image_details where id = ".. imageId)


if err then 
	ngx.log(ngx.ERR, "error in getting data from cassandra") 
	ngx.status = 500
	ngx.say("Internal server error");
	do return end
end

local imageContent = imageContentArr[1]
--orgId = "33"


if not imageContent then 
	ngx.log(ngx.ERR, "error in getting data from cassandra") 
	ngx.status = 500
	ngx.say("Internal server error");
	do return end
end


if imageContent.org_id == orgId then
	ngx.status = 200
	ngx.header.content_type = imageContent.content_type 
	ngx.say(string.sub(imageContent.content,3):fromhex())
else
	ngx.log(ngx.INFO, "Org id mismatch");
	ngx.status = 500
	ngx.say("Authentication failed");
	do return end
end

--ngx.say(err)

 

