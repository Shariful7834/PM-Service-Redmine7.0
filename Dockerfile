FROM redmine:7.0

# Since Redmine 6 the asset pipeline (Propshaft) compiles theme assets to
# public/assets/themes/, but pages link them under /themes/ — that path must be
# served explicitly (see redmine.org wiki "Themes"). Without this the theme CSS
# returns 404. The symlink lets Rails' static file server resolve /themes/*.
RUN ln -sfn assets/themes /usr/src/redmine/public/themes
