default: build

PHP_VERSION:=$(shell php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
TOOLBOX_VERSION?=dev

build: install test
.PHONY: build

install:
	composer install
.PHONY: install

update:
	composer update
.PHONY: update

update-min:
	composer update --prefer-stable --prefer-lowest
.PHONY: update-min

update-no-dev:
	composer update --prefer-stable --no-dev
.PHONY: update-no-dev

test: vendor cs deptrac phpunit infection
.PHONY: test

test-min: update-min cs deptrac phpunit infection
.PHONY: test-min

test-integration: package
	rm -rf ./build/tools && \
	  export PATH="$(shell pwd)/build/tools:$(shell pwd)/build/tools/.composer/vendor/bin:$(shell pwd)/build/tools/QualityAnalyzer/bin:$(shell pwd)/build/tools/DesignPatternDetector/bin:$(shell pwd)/build/tools/EasyCodingStandard/bin:$$PATH" && \
	  export COMPOSER_HOME=$(shell pwd)/build/tools/.composer && \
	  chmod +x build/toolbox.phar && \
	  mkdir -p ./build/tools && \
	  build/toolbox.phar install --target-dir ./build/tools --exclude-tag exclude-php:$(PHP_VERSION) && \
	  build/toolbox.phar test --target-dir ./build/tools --exclude-tag exclude-php:$(PHP_VERSION)
.PHONY: test-integration

cs: tools/php-cs-fixer
	tools/php-cs-fixer --dry-run --allow-risky=yes --no-interaction --ansi fix
.PHONY: cs

cs-fix: tools/php-cs-fixer
	tools/php-cs-fixer --allow-risky=yes --no-interaction --ansi fix
.PHONY: cs-fix

deptrac: tools/deptrac
	tools/deptrac --no-interaction --ansi --formatter-graphviz-display=0
.PHONY: deptrac

infection: tools/infection tools/infection.pubkey
	phpdbg -qrr ./tools/infection --no-interaction --formatter=progress --min-msi=100 --min-covered-msi=100 --only-covered --ansi
.PHONY: infection

phpunit: tools/phpunit
	tools/phpunit
.PHONY: phpunit

phpunit-coverage: tools/phpunit
	phpdbg -qrr tools/phpunit
.PHONY: phpunit

package: tools/box
	@rm -rf build/phar && mkdir -p build/phar build/phar/bin

	cp -r resources src LICENSE composer.json scoper.inc.php build/phar
	sed -e 's/Application('"'"'dev/Application('"'"'$(TOOLBOX_VERSION)/g' bin/toolbox.php > build/phar/bin/toolbox.php

	cd build/phar && \
	  composer config platform.php 7.1.3 && \
	  composer update --no-dev -o -a

	tools/box compile

	@rm -rf build/phar
.PHONY: package

package-devkit: tools/box
	@rm -rf build/devkit-phar && mkdir -p build/devkit-phar build/devkit-phar/bin build/devkit-phar/src

	cp -r resources LICENSE composer.json scoper.inc.php build/devkit-phar
	cp -r src/Json src/Runner src/Tool build/devkit-phar/src
	sed -e 's/\(Application(.*\)'"'"'dev/\1'"'"'$(TOOLBOX_VERSION)/g' bin/devkit.php > build/devkit-phar/bin/devkit.php

	cd build/devkit-phar && \
	  composer config platform.php 7.1.3 && \
	  composer update --no-dev -o -a

	tools/box compile -c box-devkit.json.dist

	@rm -rf build/devkit-phar
.PHONY: package-devkit

website:
	rm -rf build/website
	mkdir -p build/website
	php bin/devkit.php generate:html > build/website/index.html
	touch build/website/.nojekyll
.PHONY: website

publish-website: website
	cd build/website && \
	  git init . && \
	  git config user.email 'jakub@zalas.pl' && \
	  git config user.name 'Jakub Zalas' && \
	  git add . && \
	  git commit -m "Build the website" && \
	  git push --force --quiet "https://github.com/jakzal/toolbox.git" master:gh-pages
.PHONY: publish-website

update-phars:
	git diff --exit-code resources/ || \
	  ( \
	    (git config user.email || git config user.email 'jakub@zalas.pl') && \
	    (git config user.name || git config user.name 'Jakub Zalas') && \
	    git checkout -b tools-update && \
	    git add resources/ && \
	    git commit -m "Update tools" && \
	    git push origin tools-update && \
	    hub pull-request -h tools-update -a jakzal -m 'Update tools' \
	  )
.PHONY: update-phars

tools: tools/php-cs-fixer tools/deptrac tools/infection tools/box
.PHONY: tools

clean:
	rm -rf build
	rm -rf vendor
	find tools -not -path '*/\.*' -type f -delete
.PHONY: clean

vendor: install

vendor/bin/phpunit: install

tools/phpunit: vendor/bin/phpunit
	ln -sf ../vendor/bin/phpunit tools/phpunit

tools/php-cs-fixer:
	curl -Ls http://cs.sensiolabs.org/download/php-cs-fixer-v2.phar -o tools/php-cs-fixer && chmod +x tools/php-cs-fixer

tools/deptrac:
	curl -Ls https://github.com/sensiolabs-de/deptrac/releases/download/0.4.0/deptrac.phar -o tools/deptrac && chmod +x tools/deptrac

tools/infection: tools/infection.pubkey
	curl -Ls https://github.com/infection/infection/releases/download/0.10.6/infection.phar -o tools/infection && chmod +x tools/infection

tools/infection.pubkey:
	curl -Ls https://github.com/infection/infection/releases/download/0.10.6/infection.phar.pubkey -o tools/infection.pubkey

tools/box:
	curl -Ls https://github.com/humbug/box/releases/download/3.4.0/box.phar -o tools/box && chmod +x tools/box
