/*
 * Copyright (c) 2022 Keira Dueck <sylae@calref.net>
 * Use of this source code is governed by the MIT license, which
 * can be found in the LICENSE file.
 */

class ServerCommunicator {

    string baseURL;
    string apiKey;

    string errorMsg;

    bool asyncInProgress = false;

    ServerCommunicator() {}

    ServerCommunicator(const string &in baseURL, const string &in apiKey) {
        this.baseURL = baseURL;
        this.apiKey = apiKey;
    }

    Json::Value baseAPIObject() {
    	Json::Value json = Json::Object();
    	json["apiKey"] = apiKey;
    	return json;
    }

    void getMapInfo(TrackRating &out data, TrackRatingsTrack &in map, TrackRatingsPlayer &in player) {
        Json::Value payload = this.baseAPIObject();
	    payload["playerInfo"] = player.jsonEncode();
	    payload["trackInfo"] = map.jsonEncode();

        Json::Value result;
        if (genericAPIPost("/api/mapinfo", payload, result, false)) {
            trace("Fetched map info");
            trace(Json::Write(result));
            data.upCount = result["vUp"];
            data.downCount = result["vDown"];
			try {
				data.yourVote = result["myvote"];
			} catch {
				data.yourVote = "O"; // bad token prolly, ignore since it doesnt matter here
			}
        } else {
            trace("Map invalid");
            trace(Json::Write(result));
            trace(errorMsg);
        }
    }

    void vote(const string &in vote, TrackRating &out data, TrackRatingsTrack &in map, TrackRatingsPlayer &in player) {
        Json::Value payload = this.baseAPIObject();
	    payload["playerInfo"] = player.jsonEncode();
	    payload["trackInfo"] = map.jsonEncode();
	    payload["vote"] = vote;

        Json::Value result;
        if (genericAPIPost("/api/vote", payload, result)) {
            trace("Vote successful");
            trace(Json::Write(result));
            data.upCount = result["vUp"];
            data.downCount = result["vDown"];
			try {
				data.yourVote = result["myvote"];
			} catch {
				data.yourVote = "O"; // bad token prolly, ignore since it doesnt matter here
			}
        } else {
            trace("Vote invalid");
            trace(Json::Write(result));
            trace(errorMsg);
        }
    }

    bool checkKeyStatus() {
        Json::Value payload = this.baseAPIObject();

        Json::Value result;
        if (genericAPIPost("/api/keystatus", payload, result)) {
            return true;
        } else {
            trace("Key invalid");
            trace(Json::Write(result));
            trace(errorMsg);
            return false;
        }
    }

#if DEPENDENCY_AUTH
    string fetchAPIKey(TrackRatingsPlayer &in player) {
        asyncInProgress = true;

        // get a token from the mothership
        string token = Auth::GetTokenAsync();
        if (token == "") {
            errorMsg = "Unable to automatically auth, see Settings->API.";
            asyncInProgress = false;
            return "";
        }

        Json::Value json = Json::Object();
        json["token"] = token;
        json["login"] = player.login;
        json["clubTag"] = player.clubTag;

        Json::Value result;
        if (genericAPIPost("/auth/openplanet", json, result, false)) {
			UI::ShowNotification("TrackRatings", "Successfully authenticated with Openplanet!");
            return result["apiKey"];
        } else {
            errorMsg = "Unable to automatically auth, see Settings->API.";
            trace(Json::Write(result));
            return "";
        }
    }
#endif

    bool genericAPIPost(string _endpoint, Json::Value payload, Json::Value &out result, bool requireKey = true) {
        if (requireKey && apiKey.Length == 0) {
            errorMsg = "No API key entered, please go to Settings";
            return false;
        }

        asyncInProgress = true;
        auto req = APIReq(baseURL + _endpoint, payload);
        while (!req.Finished()) {
            yield();
        }

        try {
            result = Json::Parse(req.String());

            if (result.GetType() == Json::Type::Null) {
                throw("not json");
            }

        } catch {
            errorMsg = "JSON parse error, see Openplanet log";
            trace(req.String());
            trace(req.ResponseCode());
            return false;
        }

        if(req.ResponseCode() == 200) {
            errorMsg = "";
            asyncInProgress = false;
            return true;
        } else {
            trace(req.String());
            trace(req.ResponseCode());
            errorMsg = result["_error"];
            asyncInProgress = false;
            return false;
        }
    }

    Net::HttpRequest@ APIReq(string &in url, Json::Value json)
    {
    	auto ret = Net::HttpPost(url, Json::Write(json), "application/json");
    	return ret;
    }

}