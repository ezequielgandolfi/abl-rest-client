using Progress.Json.ObjectModel.*.
using Progress.Lang.*.
using com.ziki.rest.*.
 
class com.ziki.rest.RestClient:
    
    def private var hConnection as handle no-undo.

    // Properties
    def public property url as character
    get. set.
    
    def public property methodPath as character
    get. set.
    
    def public property requestTimeout as decimal
    get. set.

    def public property request as RestRequest
    get. set.

    def public property response as RestResponse
    get. set.

    constructor public RestClient():
        assign this-object:url                = "http://localhost"
               this-object:methodPath         = ""
               this-object:requestTimeout     = 60
               this-object:request            = new RestRequest()
               this-object:response           = new RestResponse().
    end.
    
    destructor public RestClient():
        this-object:closeConnection().

        if valid-object(this-object:request)
        then delete object this-object:request.
        if valid-object(this-object:response)
        then delete object this-object:response.
    end.

    //
    method private void parseServerUrl(input cUrl as char, output cServer as char, output cPort as char, output cPath as char):
        
        assign cUrl = replace(cUrl, "http://", "").

        if num-entries(cUrl, "/") = 1
        then assign cUrl = entry(1, cUrl, "/")
                    cPath = "/".
        else assign cPath = substring(cUrl, index(cUrl, "/"))
                    cUrl = entry(1, cUrl, "/").

        if num-entries(cUrl, ":") = 1
        then assign cServer = entry(1, cUrl, ":")
                    cPort   = "80".
        else assign cServer = entry(1, cUrl, ":")
                    cPort   = entry(2, cUrl, ":").

    end method.

    // Auth
    method public char basicAuthenticate(input userName as char, input password as char):
        def var cToken as char no-undo.
        def var mToken as memptr no-undo.

        assign cToken = userName + ":" + password
               set-size(mToken) = 0
               set-size(mToken) = length(cToken)
               put-string(mToken, 1, length(cToken)) = cToken
               cToken = "Basic " + string(base64-encode(mToken))
               set-size(mToken) = 0.

        this-object:request:authorizationToken = cToken.

        return cToken.
    end method.

    // GET
    method public JsonObject get():
        return this-object:get("", new JsonObject()).
    end method.
    
    method public JsonObject get(input json as JsonConstruct):
        return this-object:get("", json).
    end method.
    
    method public JsonObject get(input path as character):
        return this-object:get(path, new JsonObject()).
    end method.
    
    method public JsonObject get(input path as character, input json as JsonConstruct):
        return this-object:execute("get", path, json).
    end method.
    
    // POST
    method public JsonObject post():
        return this-object:post("", new JsonObject()).
    end method.
    
    method public JsonObject post(input json as JsonConstruct):
        return this-object:post("", json).
    end method.
    
    method public JsonObject post(input path as character):
        return this-object:post(path, new JsonObject()).
    end method.
    
    method public JsonObject post(input path as character, input json as JsonConstruct):
        return this-object:execute("post", path, json).
    end method.
    
    // PUT
    method public JsonObject put():
        return this-object:put("", new JsonObject()).
    end method.
    
    method public JsonObject put(input json as JsonConstruct):
        return this-object:put("", json).
    end method.
    
    method public JsonObject put(input path as character):
        return this-object:put(path, new JsonObject()).
    end method.
    
    method public JsonObject put(input path as character, input json as JsonConstruct):
        return this-object:execute("put", path, json).
    end method.
    
    // DELETE
    method public JsonObject delete():
        return this-object:delete("", new JsonObject()).
    end method.
    
    method public JsonObject delete(input json as JsonConstruct):
        return this-object:delete("", json).
    end method.
    
    method public JsonObject delete(input path as character):
        return this-object:delete(path, new JsonObject()).
    end method.
    
    method public JsonObject delete(input path as character, input json as JsonConstruct):
        return this-object:execute("delete", path, json).
    end method.

    method private void closeConnection():
        if valid-handle(hConnection)
        then do:
            hConnection:disconnect() no-error.
            delete object hConnection.
        end.
    end method.

    method private JsonObject longcharToJsonObject(input lcJson as longchar):
        def var oJsonOutput as JsonObject no-undo.
        def var oParse as ObjectModelParser no-undo.

        if lcJson = ?
        or lcJson = ""
        then return ?.

        assign oJsonOutput = new JsonObject()
               oParse      = new ObjectModelParser()
               oJsonOutput = cast(oParse:Parse(lcJson), JsonObject).

        delete object oParse.

        return oJsonOutput.
    end method.
    
    method protected JsonObject execute(input cMethodPar as character, input cPathPar as character, input oJsonData as JsonConstruct):

        def var cServerAux as char no-undo.
        def var cPortAux as char no-undo.
        def var cPathAux as char no-undo.
        def var mRequestAux as memptr no-undo.
        def var lcRequestAux as longchar no-undo.
        def var lcBodyAux as longchar no-undo.
        def var oJsonResult as JsonObject no-undo.
        def var hSocketHelperAux as handle no-undo.
        def var lcResponseAux as longchar no-undo.
        def var iAttemptAux as int no-undo.

        this-object:parseServerUrl(this-object:url, output cServerAux, output cPortAux, output cPathAux).
        assign cPathAux = cPathAux + this-object:methodPath + cPathPar.

        // force any connection to close
        this-object:closeConnection().
        // open new connection
        create socket hConnection no-error.
        if not error-status:error
        then do:
            hConnection:connect("-H " + cServerAux + " -S " + cPortAux) no-error.
            if not hConnection:connected()
            then delete object hConnection.
        end.

        if (not valid-handle(hConnection))
        or (not hConnection:connected())
        then return ?.

        run com/ziki/rest/RestSocketHelper.p persistent set hSocketHelperAux no-error.
        if (error-status:error)
        or (not valid-handle(hSocketHelperAux))
        then return ?.
        run reset in hSocketHelperAux.

        if oJsonData <> ?
        then do:
            assign lcBodyAux = "".
            oJsonData:write(input-output lcBodyAux).
            this-object:request:setBody(lcBodyAux).
        end.
        else this-object:request:setBody("").

        hConnection:set-read-response-procedure("onReadResponse", hSocketHelperAux).
        if this-object:requestTimeout > 0
        then hConnection:set-socket-option("SO-RCVTIMEO", string(this-object:requestTimeout)).

        assign lcRequestAux = upper(cMethodPar) + " " + cPathAux + " HTTP/1.0~r~n"
                            + this-object:request:getMessage().

        set-size(mRequestAux) = 0.
        set-size(mRequestAux) = length(lcRequestAux).
        set-byte-order(mRequestAux) = big-endian.
        put-string(mRequestAux, 1, length(lcRequestAux)) = lcRequestAux.
        hConnection:write(mRequestAux, 1, length(lcRequestAux)).
        set-size(mRequestAux) = 0.

        repeat:
            wait-for read-response of hConnection.
            if (not valid-handle(hConnection))
            or (not hConnection:connected())
            or (hConnection:get-bytes-available() = 0)
            then leave.
        end.

        assign iAttemptAux = 1.
        READ_SOCKET_RETURN:
        repeat:
            run responseAsMemptr in hSocketHelperAux (output mRequestAux).

            assign lcResponseAux = "".
            copy-lob from mRequestAux to lcResponseAux convert source codepage 'utf-8'.
            this-object:response:parseResponse(lcResponseAux).

            assign oJsonResult = this-object:longcharToJsonObject(this-object:response:body) no-error.
            if error-status:error
            or oJsonResult = ?
            then do:
                if  (this-object:response:status <> 204)
                and (iAttemptAux < 3)
                and (valid-handle(hConnection))
                and (hConnection:connected())
                then do:
                    assign iAttemptAux = iAttemptAux + 1.
                    wait-for read-response of hConnection pause 0.010.
                    next READ_SOCKET_RETURN.
                end.
            end.

            return oJsonResult.
        end.

        finally:
            this-object:closeConnection() no-error.

            if valid-handle(hSocketHelperAux)
            then delete procedure hSocketHelperAux.
        end finally.

    end method.   

end class.
