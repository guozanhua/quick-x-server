
local ServerAppBase = class("ServerAppBase")

ServerAppBase.APP_RUN_EVENT          = "APP_RUN_EVENT"
ServerAppBase.APP_QUIT_EVENT         = "APP_QUIT_EVENT"
ServerAppBase.CLIENT_ABORT_EVENT     = "CLIENT_ABORT_EVENT"

function ServerAppBase:ctor(config)
    cc.GameObject.extend(self)
    self:addComponent("components.behavior.EventProtocol"):exportMethods()

    self.isRunning = true
    self.config = clone(totable(config))
    self.config.appModuleName = config.appModuleName or "app"
    self.config.actionPackage = config.actionPackage or "actions"
    self.config.actionModuleSuffix = config.actionModuleSuffix or "Action"
end

function ServerAppBase:run()
    self:dispatchEvent({name = ServerAppBase.APP_RUN_EVENT})
    local ret = self:runEventLoop()
    self.isRunning = false
    self:dispatchEvent({name = ServerAppBase.APP_QUIT_EVENT, ret = ret})
end

function ServerAppBase:runEventLoop()
    throw(ERR_SERVER_OPERATION_FAILED, "ServerAppBase:runEventLoop() - must override in inherited class")
end

function ServerAppBase:doRequest(actionName, data)
    local actionModuleName, actionMethodName = self:normalizeActionName(actionName)
    actionModuleName = string.format("%s.%s%s", self.config.actionPackage, string.ucfirst(actionModuleName), self.config.actionModuleSuffix)
    actionMethodName = actionMethodName .. "Action"

    local actionModule = self:require(actionModuleName)
    local action = actionModule.new(self)
    local method = action[actionMethodName]
    if type(method) ~= "function" then
        throw(ERR_SERVER_INVALID_ACTION, "invalid action %s:%s", actionModuleName, actionMethodName)
    end

    if not data then
        data = self.requestParameters or {}
    end
    return method(action, data)
end

function ServerAppBase:require(moduleName)
    moduleName = self.config.appModuleName .. "." .. moduleName
    return require(moduleName)
end

function ServerAppBase:normalizeActionName(actionName)
    local actionName = actionName or (self.GET.action or "index.index")
    actionName = string.gsub(actionName, "[^%a.]", "")
    actionName = string.gsub(actionName, "^[.]+", "")
    actionName = string.gsub(actionName, "[.]+$", "")

    local parts = string.split(actionName, ".")
    if #parts == 1 then parts[2] = 'index' end
    return parts[1], parts[2]
end

function ServerAppBase:newRedis(config)
    local redis = cc.server.RedisEasy.new(config or self.config.redis)
    local ok, err = redis:connect()
    if not ok then
        throw(ERR_SERVER_OPERATION_FAILED, "failed to connect redis, %s", err)
    end
    return redis
end

function ServerAppBase:getRedis()
    if not self.redis then
        self.redis = self:newRedis()
    end
    return self.redis
end

function ServerAppBase:newBeanstalkd(config)
    local bean = cc.server.BeanstalkdEasy.new(config or self.config.beanstalkd)
    local ok, err = bean:connect()
    if not ok then
        throw(ERR_SERVER_OPERATION_FAILED, "failed to connect beanstalkd, %s", err)
    end
    return bean
end

function ServerAppBase:getBeanstalkd()
    if not self.beanstalkd then
        self.beanstalkd = self:newBeanstalkd()
    end
    return self.beanstalkd
end

return ServerAppBase
