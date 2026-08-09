function enrich_container_name(tag, timestamp, record)
    local filename = record["filename"]
    if filename then
        local container_id = filename:match("/containers/([^/]+)/")
        if container_id then
            local config_path = "/var/lib/docker/containers/" .. container_id .. "/config.v2.json"
            local f = io.open(config_path, "r")
            if f then
                local content = f:read("*all")
                f:close()
                local name = content:match('"Name":"/?([^"]+)"')
                if name then
                    record["container"] = name
                end
            end
            if not record["container"] then
                record["container"] = container_id
            end
        end
        record["filename"] = nil
    end
    record["host"] = "vps"
    return 1, timestamp, record
end
