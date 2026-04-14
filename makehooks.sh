#!/bin/sh
NAME=$(awk -F'"' '/"name": ".+"/{ print $4; exit; }' ./package.json)
echo "Adding git hooks to ${NAME} ..."

echo "Creating a temporary directory ..."
tmp_dir=$(mktemp -d)

echo "Cloning the Epimorphics githooks from the repo into ${tmp_dir} ..."
git clone -q git@github.com:epimorphics/githooks.git "${tmp_dir}"

echo "Creating new hooks directory ..."
mkdir -p ./.githooks/

echo "Copying hooks from cloned repository ..."
cp -R -fi "${tmp_dir}"/hooks/ ./.githooks/

echo "Removing temporary directory ..."
rm -rf "${tmp_dir}"

echo "Renaming hooks and setting permissions..."
for f in ./.githooks/*; do mv -f "$f" "${f%.sh}"; done
for f in ./.githooks/*; do chmod +x "$f"; done

echo "Setting hooks path to git config ..."
git config core.hooksPath './.githooks'

echo "Adding new hooks to source control ..."
git add .

echo "Committing hooks ..."
git commit -m "Added git hooks to ${NAME}"

echo "Git hooks have been added to ${NAME} and will now run the pre-commit hook"
