%% ===================================================================
%% crystal_auth - The single place that decides "may this socket speak
%% for this user id?"
%%
%% PRODUCTION MODE (recommended):
%%   Set the SUPABASE_JWT_SECRET environment variable to your Supabase
%%   project's JWT secret (Dashboard -> Settings -> API -> JWT Secret,
%%   or `supabase secrets list`). Every auth frame must then carry a
%%   valid Supabase access token signed with HS256 whose "sub" matches
%%   the claimed user_id and whose "exp" has not passed:
%%
%%     {"type":"auth","user_id":"<sub>","token":"<access_token>"}
%%
%%   Signature, algorithm ("none" is rejected), expiry (30s clock-skew
%%   grace) and subject are all verified here.
%%
%% DEVELOPMENT MODE:
%%   With no secret configured the server falls back to trust-the-id
%%   so local development stays zero-config. A warning is logged once
%%   at startup so an accidental production deploy cannot go unnoticed.
%%
%% Every other module funnels through verify/2 - hardening lives here.
%% ===================================================================
-module(crystal_auth).

-export([verify/2, mode/0]).

-define(CLOCK_SKEW_S, 30).
-define(ALLOWED_ALG, <<"HS256">>).

-type token() :: undefined | binary().

%% ------------------------------------------------------------------
%% Public API
%% ------------------------------------------------------------------

-spec mode() -> enforced | dev_trust.
mode() ->
    case jwt_secret() of
        <<>> -> dev_trust;
        _ -> enforced
    end.

-spec verify(UserId :: binary(), Token :: token()) ->
    ok | {error, Reason :: atom()}.
verify(UserId, Token) when is_binary(UserId), byte_size(UserId) > 0 ->
    case jwt_secret() of
        <<>> ->
            %% Development: no secret configured, trust the id.
            ok;
        Secret when is_binary(Token), byte_size(Token) > 0 ->
            verify_jwt(UserId, Token, Secret);
        _ ->
            {error, token_required}
    end;
verify(_UserId, _Token) ->
    {error, invalid_user}.

%% ------------------------------------------------------------------
%% JWT verification (HS256) using only OTP's built-in crypto/base64.
%% ------------------------------------------------------------------

verify_jwt(UserId, Token, Secret) ->
    case binary:split(Token, <<".">>, [global]) of
        [HeaderB64, PayloadB64, SigB64] ->
            SigningInput = <<HeaderB64/binary, $., PayloadB64/binary>>,
            ExpectedSig = crypto:mac(hmac, sha256, Secret, SigningInput),
            case safe_b64url_decode(SigB64) of
                {ok, Sig} when byte_size(Sig) =:= byte_size(ExpectedSig) ->
                    case crypto:hash_equals(ExpectedSig, Sig) of
                        true -> check_claims(UserId, HeaderB64, PayloadB64);
                        false -> {error, bad_signature}
                    end;
                {ok, _} ->
                    {error, bad_signature};
                {error, _} ->
                    {error, bad_token}
            end;
        _ ->
            {error, malformed_token}
    end.

check_claims(UserId, HeaderB64, PayloadB64) ->
    case safe_b64url_decode(HeaderB64) of
        {ok, HeaderJson} ->
            Header = safe_json_decode(HeaderJson),
            case maps:get(<<"alg">>, Header, undefined) of
                ?ALLOWED_ALG ->
                    check_payload(UserId, PayloadB64);
                _ ->
                    %% Rejects "none", RS*, and anything unexpected.
                    {error, unsupported_alg}
            end;
        {error, _} ->
            {error, bad_token}
    end.

check_payload(UserId, PayloadB64) ->
    case safe_b64url_decode(PayloadB64) of
        {ok, PayloadJson} ->
            Claims = safe_json_decode(PayloadJson),
            Sub = maps:get(<<"sub">>, Claims, undefined),
            Exp = maps:get(<<"exp">>, Claims, undefined),
            Role = maps:get(<<"role">>, Claims, undefined),
            Now = os:system_time(second),
            if
                not is_binary(Sub); Sub =/= UserId ->
                    {error, subject_mismatch};
                not is_integer(Exp) ->
                    {error, missing_exp};
                Exp + ?CLOCK_SKEW_S < Now ->
                    {error, token_expired};
                Role =/= undefined, Role =/= <<"authenticated">>,
                           Role =/= <<"anon">> ->
                    {error, bad_role};
                true ->
                    ok
            end;
        {error, _} ->
            {error, bad_token}
    end.

%% ------------------------------------------------------------------
%% Helpers
%% ------------------------------------------------------------------

jwt_secret() ->
    case os:getenv("SUPABASE_JWT_SECRET") of
        false -> <<>>;
        "" -> <<>>;
        Raw -> unicode:characters_to_binary(Raw)
    end.

%% Base64url decode that tolerates missing padding and works on every
%% supported OTP release (normalizes to the standard alphabet first).
safe_b64url_decode(Bin) ->
    Normalized = binary:replace(
        binary:replace(Bin, <<"-">>, <<"+">>, [global]),
        <<"_">>, <<"/">>, [global]
    ),
    Padded = case byte_size(Normalized) rem 4 of
        2 -> <<Normalized/binary, "==">>;
        3 -> <<Normalized/binary, "=">>;
        _ -> Normalized
    end,
    try
        {ok, base64:decode(Padded)}
    catch
        _:_ -> {error, bad_base64}
    end.

safe_json_decode(Json) ->
    try
        jsone:decode(Json)
    catch
        _:_ -> #{}
    end.
