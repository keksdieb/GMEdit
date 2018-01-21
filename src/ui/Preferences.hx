package ui;
import ace.AceWrap;
import electron.FileSystem;
import gml.GmlAPI;
import haxe.Json;
import haxe.io.Path;
import js.html.Element;
import js.html.MouseEvent;
import js.html.Window;
import Main.document;
import tools.Dictionary;

/**
 * User preferences are managed here!
 * Currently everything is just dumped into LocalStorage in JSON format.
 * @author YellowAfterlife
 */
class Preferences {
	public static var path:String = "user-preferences";
	public static var current:PrefData;
	public static var element:Element;
	//
	private static function build(out:Element) {
		function addRadios(legend:String, current:String, names:Array<String>, fn:String->Void) {
			var fs = document.createFieldSetElement();
			var lg = document.createLegendElement();
			lg.innerText = legend;
			fs.appendChild(lg);
			for (name in names) {
				var rad = document.createInputElement();
				rad.type = "radio";
				rad.name = legend;
				rad.value = name;
				rad.addEventListener("change", function(_) {
					fn(name);
				});
				if (current == name) rad.checked = true;
				var lb = document.createLabelElement();
				lb.htmlFor = name;
				lb.appendChild(document.createTextNode(name));
				fs.appendChild(rad);
				fs.appendChild(lb);
				fs.appendChild(document.createBRElement());
			}
			out.appendChild(fs);
		}
		function addCheckbox(legend:String, current:Bool, fn:Bool->Void):Element {
			var ctr = document.createDivElement();
			var cb = document.createInputElement();
			cb.type = "checkbox";
			cb.checked = current;
			cb.name = legend;
			cb.addEventListener("change", function(_) {
				fn(cb.checked);
			});
			ctr.appendChild(cb);
			var lb = document.createLabelElement();
			lb.htmlFor = legend;
			lb.appendChild(document.createTextNode(legend));
			ctr.appendChild(lb);
			out.appendChild(ctr);
			return ctr;
		}
		function addInput(legend:String, current:String, fn:String->Void):Element {
			var ctr = document.createDivElement();
			//
			var lb = document.createLabelElement();
			lb.htmlFor = legend;
			lb.appendChild(document.createTextNode(legend));
			ctr.appendChild(lb);
			//
			var cb = document.createInputElement();
			cb.type = "text";
			cb.value = current;
			cb.name = legend;
			cb.addEventListener("change", function(_) {
				fn(cb.value);
			});
			ctr.appendChild(cb);
			//
			out.appendChild(ctr);
			return ctr;
		}
		function addButton(text:String, fn:Void->Void):Element {
			var ctr = document.createDivElement();
			var el = document.createAnchorElement();
			el.href = "#";
			el.appendChild(document.createTextNode(text));
			el.addEventListener("click", function(e:MouseEvent) {
				e.preventDefault();
				fn();
			});
			ctr.appendChild(el);
			out.appendChild(ctr);
			return ctr;
		}
		//
		var themeList = ["default"];
		for (name in FileSystem.readdirSync(Main.relPath(Theme.path))) {
			if (name == "default") continue;
			var full = Path.join([Main.modulePath, Theme.path, name, "config.json"]);
			if (FileSystem.existsSync(full)) themeList.push(name);
		}
		addRadios("Theme", current.theme, themeList, function(theme) {
			current.theme = theme;
			Theme.current = theme;
			save();
		});
		addCheckbox("Use `#args` magic", current.argsMagic, function(z) {
			current.argsMagic = z;
			save();
		}).title = "Allows writing `#args a, b` instead of `var a = argument0, b = argument1`."
			+ "\nSee wiki for examples and more information.";
		addCheckbox("UK spelling", current.ukSpelling, function(z) {
			current.ukSpelling = z;
			GmlAPI.ukSpelling = z;
			GmlAPI.init();
			save();
		}).title = "Displays UK versions of function/variable names (e.g. draw_set_colour) in auto-completion when available.";
		addCheckbox("Show asset thumbnails", current.assetThumbs, function(z) {
			current.assetThumbs = z;
			save();
			gml.Project.current.reload();
		}).title = "Loads and displays the assigned sprites as object thumbnails in resource tree.";
		addInput("Keep file sessions for (days):",
		"" + current.fileSessionTime, function(s) {
			current.fileSessionTime = Std.parseFloat(s); save();
		});
		addInput("Keep project sessions for (d):",
		"" + current.projectSessionTime, function(s) {
			current.fileSessionTime = Std.parseFloat(s); save();
		});
		addButton("Code Editor Settings", function() {
			AceWrap.loadModule("ace/ext/settings_menu", function(module) {
				module.init(Main.aceEditor);
				untyped Main.aceEditor.showSettingsMenu();
			});
		});
	}
	public static function open() {
		if (element == null) {
			element = document.querySelector("#preferences-window");
			build(element);
		}
		element.style.display = element.style.display != "" ? "" : "none";
	}
	public static function save() {
		Main.window.localStorage.setItem(path, Json.stringify(current));
	}
	public static function load() {
		var pref:PrefData = null;
		try {
			var data = Main.window.localStorage.getItem(path);
			pref = Json.parse(data);
		} catch (_:Dynamic) { }
		if (pref == null) {
			pref = { theme: "dark" };
			save();
		}
		//
		if (pref.argsMagic == null) pref.argsMagic = true;
		if (pref.fileSessionTime == null) pref.fileSessionTime = 7;
		if (pref.projectSessionTime == null) pref.projectSessionTime = 14;
		if (pref.theme != null) Theme.current = pref.theme;
		if (pref.assetThumbs == null) pref.assetThumbs = true;
		GmlAPI.ukSpelling = pref.ukSpelling;
		//
		current = pref;
	}
	public static function init() {
		document.querySelector(".system-button.preferences")
			.addEventListener("click", function(_) open());
		load();
	}
	public static function initEditor() {
		// load Ace options:
		try {
			var text = Main.window.localStorage.getItem("aceOptions");
			if (text != null) Main.aceEditor.setOptions(Json.parse(text));
		} catch (_:Dynamic) { };
		// flush Ace options on changes (usually only via Ctrl+,):
		var editor = Main.aceEditor;
		var origSetOption = editor.setOption;
		untyped editor.setOption = function(key, val) {
			origSetOption(key, val);
			var opts:Dictionary<Dynamic> = Main.aceEditor.getOptions();
			opts.remove("enableLiveAutocompletion");
			opts.remove("theme");
			Main.window.localStorage.setItem("aceOptions", Json.stringify(opts));
		};
		if (editor.getOption("fontFamily") == null) {
			var font = switch (untyped process.platform) {
				case "darwin": "Menlo, monospace";
				default: "Consolas, Courier New, monospace";
			}
			editor.setOption("fontFamily", font);
		}
	}
}
typedef PrefData = {
	?theme:String,
	?ukSpelling:Bool,
	?fileSessionTime:Float,
	?projectSessionTime:Float,
	?argsMagic:Bool,
	?assetThumbs:Bool,
}
