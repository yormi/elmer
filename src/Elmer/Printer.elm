module Elmer.Printer exposing
  ( Message
  , description
  , message
  , formatMessage
  , format
  )

type alias Message =
  { description: String
  , example: Maybe String
  }

description : String -> Message
description description =
  { description = description
  , example = Nothing
  }

message : String -> String -> Message
message description example =
  { description = description
  , example = Just example
  }

formatMessage : Message -> String
formatMessage message =
  case message.example of
    Just example ->
      message.description ++ "\n\n" ++ (formatExample example)
    Nothing ->
      message.description

formatExample : String -> String
formatExample example =
  String.split "\n" example
    |> List.foldl (\s msg -> msg ++ "\t" ++ s ++ "\n") ""
    |> String.trimRight

format : List Message -> String
format messages =
  List.map formatMessage messages
    |> String.join "\n\n"
