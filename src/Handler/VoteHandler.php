<?php

/*
 * Copyright (c) 2022 Keira Dueck <sylae@calref.net>
 * Use of this source code is governed by the MIT license, which
 * can be found in the LICENSE file.
 */

namespace Handler;

class VoteHandler extends \HandlerBase
{

    public static function registerRoutes(): array
    {
        return [
            ['POST', '/api/vote']
        ];
    }

    public function respond(array $vars)
    {
        try {
            $body = json_decode(file_get_contents('php://input'));
            if (json_last_error() != JSON_ERROR_NONE) {
                throw new \Exception();
            }
        } catch (\Throwable $e) {
            $this->apiError(json_last_error_msg(), 400, json_last_error());
            return;
        }

        try {
            $user = \User::createFromAPIKey($this->trs, trim($body->apiKey));

            // verify api key matches given uid
            if ($body->playerInfo->uid != $user->id) {
                throw new \InvalidArgumentException();
            }

            // since things match let's make sure user info is up-to-date...
            $user->login = $body->playerInfo->login;
            $user->clubTag = $body->playerInfo->clubTag;
            $user->displayName = $body->playerInfo->displayNameClean;
            $user->update();
            $this->trs->log("openplanet_vote", user: $user);
        } catch (\InvalidArgumentException $e) {
            $this->apiError("Unable to authenticate user, please recycle your API token", 401);
            return;
        }

        try {
            $map = \Map::createFromJSONIngest($this->trs, $body->trackInfo, $user);

            // try and get TMX data while we're here
            $map->fetchTMXid();

            // try to vote
            $map->addVote($user, $body->vote, $body->pb ?? null);

            // return vote totals
            echo $map->getMapSummaryJSON($user);
        } catch (\Throwable $e) {
            $this->apiError("Unknown map parse error. Please try again", 500, $e->getMessage());
        }
    }
}
