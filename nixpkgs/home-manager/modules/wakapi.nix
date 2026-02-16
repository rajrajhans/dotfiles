{ pkgs, config, lib, ... }:

let
  wakapiPkg = pkgs.callPackage ../../wakapi.nix { };
  homeDir = config.home.homeDirectory;
  dataDir = ".local/share/wakapi";
  absDataDir = "${homeDir}/${dataDir}";
  dotfilesDir = "${homeDir}/dotfiles";
in
{
  home.packages = [ wakapiPkg ];

  # Wakapi server config
  home.file."${dataDir}/config.yml".text = ''
    env: production
    quick_start: false
    skip_migrations: false

    server:
      listen_ipv4: 127.0.0.1
      listen_ipv6: ::1
      timeout_sec: 30
      port: 5050
      base_path: /
      public_url: http://localhost:5050

    app:
      leaderboard_enabled: true
      leaderboard_scope: 7_days
      leaderboard_generation_time: '0 0 6 * * *,0 0 18 * * *'
      aggregation_time: '0 15 2 * * *'
      report_time_weekly: '0 0 18 * * 5'
      data_cleanup_time: '0 0 6 * * 0'
      inactive_days: 7
      import_enabled: true
      import_backoff_min: 5
      import_max_rate: 24
      import_batch_size: 50
      heartbeat_max_age: '4320h'
      data_retention_months: -1
      custom_languages:
        vue: Vue
        jsx: JSX
        tsx: TSX
        cjs: JavaScript
        ipynb: Python
        svelte: Svelte
        astro: Astro
      avatar_url_template: api/avatar/{username_hash}.svg

    db:
      name: wakapi_db.db
      dialect: sqlite3
      max_conn: 2

    security:
      insecure_cookies: true
      cookie_max_age: 172800
      allow_signup: true

    sentry:
      dsn:

    subscriptions:
      enabled: false

    mail:
      enabled: false
  '';

  # Generate ~/.wakatime.cfg at activation time from .env / .env.local
  home.activation.generateWakatimeCfg = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Source .env defaults, then .env.local overrides
    set -a
    [ -f "${dotfilesDir}/.env" ] && . "${dotfilesDir}/.env"
    [ -f "${dotfilesDir}/.env.local" ] && . "${dotfilesDir}/.env.local"
    set +a

    cat > "${homeDir}/.wakatime.cfg" <<EOF
    [settings]
    api_url = http://localhost:5050/api
    api_key = $WAKAPI_API_KEY
    EOF
  '';

  # Launchd agent to start wakapi at login
  launchd.agents.wakapi = {
    enable = true;
    config = {
      Label = "com.rajrajhans.wakapi";
      ProgramArguments = [ "${wakapiPkg}/bin/wakapi" ];
      WorkingDirectory = absDataDir;
      EnvironmentVariables = {
        WAKAPI_CONFIG_FILE = "${absDataDir}/config.yml";
      };
      StandardOutPath = "${absDataDir}/logs/stdout.log";
      StandardErrorPath = "${absDataDir}/logs/stderr.log";
      RunAtLoad = true;
      KeepAlive = true;
    };
  };
}
