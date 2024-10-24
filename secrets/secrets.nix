let
  # Fetch all my public github keys to encrypt secrets with
  github-keys = builtins.readFile (builtins.fetchurl {
    url = "https://github.com/theodedeken.keys";
  });
  keys = [github-keys];
in {
  # API key for notion
  "TF_VAR_notion_api_key.age".publicKeys = keys;
  # Id of the notion database we collect emails in
  "TF_VAR_notion_db_id.age".publicKeys = keys;
  # GCP service account credentials
  "GOOGLE_APPLICATION_CREDENTIALS.age".publicKeys = keys;
}
