using com.ziki.rest.*.
using Progress.Json.ObjectModel.*.

run example-get.
run example-post.

procedure example-get:

    def var oRest as RestClient no-undo.
    def var oJson as JsonObject no-undo.

    oRest = new RestClient().
    oRest:url = "http://localhost:8080/myApi".
    oRest:basicAuthenticate("user", "password").
    oJson = oRest:get("/v1/example/?filter=XYZ").

    if oJson <> ?
    then oJson:writefile("c:/temp/response.json").

    message
        "Status" oRest:response:status skip
        "Response" skip
        string(oRest:response:body)
        view-as alert-box.

    finally:
        if valid-object(oRest)
        then delete object oRest.
    end finally.

end.

procedure example-post:

    def var oRest as RestClient no-undo.
    def var oJson as JsonObject no-undo.

    oJson = new JsonObject().
    oJson:add("anyInfo", "XYZ").

    oRest = new RestClient().
    oRest:url = "http://localhost:8080/myApi".
    oRest:basicAuthenticate("user", "password").
    oJson = oRest:get("/v1/example/", oJson).

    if oJson <> ?
    then oJson:writefile("c:/temp/response.json").

    message
        "Status" oRest:response:status skip
        "Response" skip
        string(oRest:response:body)
        view-as alert-box.

    finally:
        if valid-object(oRest)
        then delete object oRest.
    end finally.

end.
