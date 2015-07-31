'use strict'

gulp        = require 'gulp'
loadPlugins = require 'gulp-load-plugins'

$ = loadPlugins
	pattern: ['*']

browserSync = $.browserSync.create()

config =
	vendorPrefixes: ['> 1%', 'last 2 versions', 'Firefox ESR', 'Opera 12.1'], # See: https://github.com/ai/browserslist#queries
	paths:
		jade:
			base: 'app'
			watch: ['app/*.jade', '!app/_*.jade']
			src: 'app/*.jade'
			dest: '.tmp'
		sass:
			base: 'app/styles'
			watch: ['app/styles/**/*.scss']
			src: 'app/styles/*.scss'
			dest: '.tmp/styles'
		coffee:
			base: 'app/scripts'
			watch: ['app/scripts/**/*.coffee']
			src: ['app/scripts/*.coffee']
			dest: '.tmp/scripts'
		sprites:
			watch: 'app/images/sprites/*.png'
			src: 'app/images/sprites/*.png'
			dest: 'app/images'
		imagemin:
			src: ['app/images/*', '!app/images/sprites']
			dest: 'dist/images'
		svgmin:
			src: 'app/images/**/*.svg'
			dest: 'dist/images'
		usemin:
			src: '.tmp/*.html'
			dest: 'dist'
	server:
		base: ['app', '.tmp']

gulp.task 'jade', ->
	gulp.src config.paths.jade.src
	.pipe $.plumber()
	.pipe $.jade()
	.on 'error', _logError
	.pipe $.flatten()
	.pipe gulp.dest config.paths.jade.dest
	.pipe browserSync.reload stream: true

gulp.task 'sass', ->
	gulp.src config.paths.sass.src
	.pipe $.sourcemaps.init()
	.pipe $.sass().on 'error', $.sass.logError
	.pipe $.autoprefixer
		browsers: config.vendorPrefixes
	.pipe $.sourcemaps.write()
	.pipe gulp.dest config.paths.sass.dest
	.pipe browserSync.reload stream: true

gulp.task 'sprites', ->
	spriteData = gulp.src config.paths.sprites.src
	.pipe $.spritesmith
		imgName: 'sprites.png'
		imgPath: '../images/sprites.png'
		cssName: '_sprites.scss'

	imgStream = spriteData.img
	.pipe gulp.dest config.paths.sprites.dest

	cssStream = spriteData.css
	.pipe gulp.dest config.paths.sass.base

	$.mergeStream imgStream, cssStream

gulp.task 'coffee', ->
	bundleScripts watch: false

gulp.task 'usemin', ->
	gulp.src config.paths.usemin.src
	.pipe $.usemin(
			css: [$.minifyCss(), 'concat']
			js: [$.uglify(), 'concat']
		).on 'error', _logError
	.pipe gulp.dest config.paths.usemin.dest

gulp.task 'imagemin', ->
	gulp.src config.paths.imagemin.src
	.pipe $.imagemin
		progress: true
		use: [$.imageminPngquant()]
	.pipe gulp.dest config.paths.imagemin.dest

gulp.task 'svgmin', ->
	gulp.src config.paths.svgmin.src
	.pipe $.svgmin()
	.pipe gulp.dest config.paths.svgmin.dest

gulp.task 'cleanTmp', (cb) ->
	$.del '.tmp/**/*', cb

gulp.task 'cleanDist', (cb) ->
	$.del [
		'dist/**/*',
		'!dist/.{svn,git}',
		'!dist/sftp-config.json'
	], cb

gulp.task 'default', ['cleanTmp'], ->
	$.runSequence 'sprites', ['jade', 'sass', 'coffee']

gulp.task 'serve', ->
	$.runSequence 'cleanTmp', 'sprites', ['jade', 'sass'], ->
		bundleScripts watch: true

		gulp.watch config.paths[task].watch, [task] for task in ['jade', 'sass', 'sprites']

		browserSync.init
			server:
				baseDir: config.server.base

gulp.task 'build', ['cleanDist'], ->
	$.runSequence ['usemin', 'imagemin', 'svgmin'], ->
		gulp.src "#{config.paths.coffee.dest}/*"
		.pipe $.uglify()
		.pipe gulp.dest 'dist/scripts'

		gulp.src "#{config.paths.sass.dest}/*"
		.pipe $.minifyCss()
		.pipe gulp.dest 'dist/styles'	

bundleScripts = (options) ->
	$.globby config.paths.coffee.src, (err, files) ->
		scripts = files.map (entry) ->
			entry = entry.replace "#{config.paths.coffee.base}/", ''

			bundler = $.browserify
				entries: ["#{config.paths.coffee.base}/#{entry}"]
				transform: ['coffeeify']
				extensions: ['.coffee']
				debug: true
			, paths: [config.paths.coffee.base]

			if options.watch is true then bundler = $.watchify(bundler)

			rebundle = ->
				bundler.bundle().on 'error', _logError
				.pipe $.vinylSourceStream entry
				.pipe $.rename
					extname: '.js'
				.pipe gulp.dest config.paths.coffee.dest
				.pipe browserSync.reload stream: true

			bundler.on 'update', rebundle

			rebundle()

_logError = (error) ->
	$.util.log error.message
	$.util.beep()