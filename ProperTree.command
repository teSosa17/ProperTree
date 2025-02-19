#!/usr/bin/env python
import sys, os, binascii, base64, json, re
from collections import OrderedDict
try:
    import Tkinter as tk
    import ttk
    import tkFileDialog as fd
    import tkMessageBox as mb
except:
    import tkinter as tk
    import tkinter.ttk as ttk
    from tkinter import filedialog as fd
    from tkinter import messagebox as mb
from Scripts import *

class ProperTree:
    def __init__(self, plists = []):
        # Create the new tk object
        self.tk = tk.Tk()
        self.tk.title("Convert Values")
        self.tk.minsize(width=640,height=130)
        self.tk.resizable(True, False)
        self.tk.columnconfigure(2,weight=1)
        self.tk.columnconfigure(3,weight=1)
        # Build the Hex <--> Base64 converter
        f_label = tk.Label(self.tk, text="From:")
        f_label.grid(row=0,column=0)
        t_label = tk.Label(self.tk, text="To:")
        t_label.grid(row=1,column=0)

        # Setup the from/to option menus
        f_title = tk.StringVar(self.tk)
        t_title = tk.StringVar(self.tk)
        f_title.set("Base64")
        t_title.set("Hex")
        f_option = tk.OptionMenu(self.tk, f_title, "Ascii", "Base64", "Decimal", "Hex", command=self.change_from_type)
        t_option = tk.OptionMenu(self.tk, t_title, "Ascii", "Base64", "Decimal", "Hex", command=self.change_to_type)
        self.from_type = "Base64"
        self.to_type   = "Hex"
        f_option.grid(row=0,column=1,sticky="we")
        t_option.grid(row=1,column=1,sticky="we")

        self.f_text = tk.Entry(self.tk)
        self.f_text.delete(0,tk.END)
        self.f_text.insert(0,"")
        self.f_text.grid(row=0,column=2,columnspan=2,sticky="we",padx=10,pady=10)

        self.t_text = tk.Entry(self.tk)
        self.t_text.configure(state='normal')
        self.t_text.delete(0,tk.END)
        self.t_text.insert(0,"")
        self.t_text.configure(state='readonly')
        self.t_text.grid(row=1,column=2,columnspan=2,sticky="we",padx=10,pady=10)

        self.c_button = tk.Button(self.tk, text="Convert", command=self.convert_values)
        self.c_button.grid(row=2,column=3,sticky="e",padx=10,pady=10)

        self.f_text.bind("<Return>", self.convert_values)
        self.f_text.bind("<KP_Enter>", self.convert_values)

        self.start_window = None 

        # Regex to find the processor serial numbers when
        # opened from the Finder
        self.regexp = re.compile(r"^-psn_[0-9]+_[0-9]+$")

        # Setup the menu-related keybinds - and change the app name if needed
        key="Control"
        sign = "Ctr+"
        if str(sys.platform) == "darwin":
            # Remap the quit function to our own
            self.tk.createcommand('::tk::mac::Quit', self.quit)
            self.tk.createcommand("::tk::mac::OpenDocument", self.open_plist_from_app)
            self.tk.createcommand("::tk::mac::ReopenApplication", self.open_plist_from_app)
            # Import the needed modules to change the bundle name and force focus
            try:
                from Foundation import NSBundle
                from Cocoa import NSRunningApplication, NSApplicationActivateIgnoringOtherApps
                app = NSRunningApplication.runningApplicationWithProcessIdentifier_(os.getpid())
                app.activateWithOptions_(NSApplicationActivateIgnoringOtherApps)
                bundle = NSBundle.mainBundle()
                if bundle:
                    info = bundle.localizedInfoDictionary() or bundle.infoDictionary()
                    if info and info['CFBundleName'] == 'Python':
                        info['CFBundleName'] = "ProperTree"
            except:
                pass
            key="Command"
            sign=key+"+"

        self.tk.protocol("WM_DELETE_WINDOW", self.close_window)
        # Close initial window
        self.close_window(None,False)

        # Setup the top level menu
        file_menu = tk.Menu(self.tk)
        main_menu = tk.Menu(self.tk)
        main_menu.add_cascade(label="File", menu=file_menu)
        file_menu.add_command(label="New ({}N)".format(sign), command=self.new_plist)
        file_menu.add_command(label="Open ({}O)".format(sign), command=self.open_plist)
        file_menu.add_command(label="Save ({}S)".format(sign), command=self.save_plist)
        file_menu.add_command(label="Save As ({}Shift+S)".format(sign), command=self.save_plist_as)
        file_menu.add_command(label="Duplicate ({}D)".format(sign), command=self.duplicate_plist)
        file_menu.add_command(label="Reload From Disk ({}L)".format(sign), command=self.reload_from_disk)
        file_menu.add_separator()
        file_menu.add_command(label="OC Snapshot ({}R)".format(sign), command=self.oc_snapshot)
        file_menu.add_separator()
        file_menu.add_command(label="Convert Window ({}T)".format(sign), command=self.show_convert)
        file_menu.add_command(label="Strip Comments ({}M)".format(sign), command=self.strip_comments)
        file_menu.add_separator()
        file_menu.add_command(label="View Data As Hex", command=lambda:self.change_data_display("hex"))
        file_menu.add_command(label="View Data As Base64", command=lambda:self.change_data_display("base64"))
        if not str(sys.platform) == "darwin":
            file_menu.add_separator()
            file_menu.add_command(label="Quit ({}Q)".format(sign), command=self.quit)
        self.tk.config(menu=main_menu)

        # Set bindings
        self.tk.bind("<{}-w>".format(key), self.close_window)
        self.tk.bind_all("<{}-n>".format(key), self.new_plist)
        self.tk.bind_all("<{}-o>".format(key), self.open_plist)
        self.tk.bind_all("<{}-s>".format(key), self.save_plist)
        self.tk.bind_all("<{}-S>".format(key), self.save_plist_as)
        self.tk.bind_all("<{}-d>".format(key), self.duplicate_plist)
        self.tk.bind_all("<{}-t>".format(key), self.show_convert)
        self.tk.bind_all("<{}-z>".format(key), self.undo)
        self.tk.bind_all("<{}-Z>".format(key), self.redo)
        self.tk.bind_all("<{}-m>".format(key), self.strip_comments)
        self.tk.bind_all("<{}-r>".format(key), self.oc_snapshot)
        self.tk.bind_all("<{}-l>".format(key), self.reload_from_disk)
        if not str(sys.platform) == "darwin":
            # Rewrite the default Command-Q command
            self.tk.bind_all("<{}-q>".format(key), self.quit)
        
        cwd = os.getcwd()
        os.chdir(os.path.dirname(os.path.realpath(__file__)))
        settings = {}
        try:
            if os.path.exists("Scripts/settings.json"):
                settings = json.load(open("Scripts/settings.json"))
        except:
            pass
        self.xcode_data = settings.get("xcode_data",True) # keep <data>xxxx</data> in one line when true
        self.sort_dict = settings.get("sort_dict",False) # Preserve key ordering in dictionaries when loading/saving
        os.chdir(cwd)

        # Wait before opening a new document to see if we need to.
        # This was annoying to debug, but seems to work.
        self.tk.after(100, lambda:self.check_open(plists))

        # Start our run loop
        tk.mainloop()

    def check_open(self, plists = []):
        plists = [x for x in plists if not self.regexp.search(x)]
        if isinstance(plists, list) and len(plists):
            # Iterate the passed plists and open them
            for p in set(plists):
                window = self.open_plist_with_path(None,p,None)
                if self.start_window == None:
                    self.start_window = window
        elif not len(self.stackorder(self.tk)):
            # create a fresh plist to start
            self.start_window = self.new_plist()

    def open_plist_from_app(self, *args):
        if isinstance(args, str):
            args = [args]
        args = [x for x in args if not self.regexp.search(x)]
        for arg in args:
            # Let's load the plist
            if self.start_window == None:
                self.start_window = self.open_plist_with_path(None,arg,None)
            elif self.start_window.current_plist == None:
                self.open_plist_with_path(None,arg,self.start_window)
            else:
                self.open_plist_with_path(None,arg,None)

    def change_hd_type(self, value):
        self.hd_type = value

    def reload_from_disk(self, event = None):
        windows = self.stackorder(self.tk)
        if not len(windows):
            # Nothing to do
            return
        window = windows[-1] # Get the last item (most recent)
        if window == self.tk:
            return
        window.reload_from_disk(event)

    def change_data_display(self, new_data = None):
        windows = self.stackorder(self.tk)
        if not len(windows):
            # Nothing to do
            return
        window = windows[-1] # Get the last item (most recent)
        if window == self.tk:
            return
        window.change_data_display(new_data)

    def oc_snapshot(self, event = None):
        windows = self.stackorder(self.tk)
        if not len(windows):
            # Nothing to do
            return
        window = windows[-1] # Get the last item (most recent)
        if window == self.tk:
            return
        window.oc_snapshot(event)

    def close_window(self, event = None, check_close = True):
        # Remove the default window that comes from it
        #if str(sys.platform) == "darwin":
        #    self.tk.iconify()
        #else:
        self.tk.withdraw()
        if check_close:
            windows = self.stackorder(self.tk)
            if not len(windows):
                # Quit if all windows are closed
                self.quit()

    def strip_comments(self, event = None):
        windows = self.stackorder(self.tk)
        if not len(windows):
            # Nothing to do
            return
        window = windows[-1] # Get the last item (most recent)
        if window == self.tk:
            return
        window.strip_comments(event)

    def change_to_type(self, value):
        self.to_type = value
        self.convert_values()

    def change_from_type(self, value):
        self.from_type = value

    def show_convert(self, event = None):
        self.tk.deiconify()

    def convert_values(self, event = None):
        from_value = self.f_text.get()
        if not len(from_value):
            # Empty - nothing to convert
            return
        # Pre-check for hex potential issues
        if self.from_type.lower() == "hex":
            if from_value.lower().startswith("0x"):
                from_value = from_value[2:]
            from_value = from_value.replace(" ","").replace("<","").replace(">","")
            if [x for x in from_value if x.lower() not in "0123456789abcdef"]:
                self.tk.bell()
                mb.showerror("Invalid Hex Data","Invalid character in passed hex data.",parent=self.tk)
                return
        try:
            if self.from_type.lower() == "decimal":
                # Convert to hex bytes
                from_value = "{:x}".format(int(from_value))
                if len(from_value) % 2:
                    from_value = "0"+from_value
            # Handle the from data
            if sys.version_info >= (3,0):
                # Convert to bytes
                from_value = from_value.encode("utf-8")
            if self.from_type.lower() == "base64":
                from_value = base64.b64decode(from_value)
            elif self.from_type.lower() in ["hex","decimal"]:
                from_value = binascii.unhexlify(from_value)
            # Let's get the data converted
            to_value = from_value
            if self.to_type.lower() == "base64":
                to_value = base64.b64encode(from_value)
            elif self.to_type.lower() == "hex":
                to_value = binascii.hexlify(from_value)
            elif self.to_type.lower() == "decimal":
                to_value = str(int(binascii.hexlify(from_value),16))
            if sys.version_info >= (3,0) and not self.to_type.lower() == "decimal":
                # Convert to bytes
                to_value = to_value.decode("utf-8")
            if self.to_type.lower() == "hex":
                # Capitalize it, and pad with spaces
                to_value = "{}".format(" ".join((to_value[0+i:8+i] for i in range(0, len(to_value), 8))).upper())
            # Set the text box
            self.t_text.configure(state='normal')
            self.t_text.delete(0,tk.END)
            self.t_text.insert(0,to_value)
            self.t_text.configure(state='readonly')
        except Exception as e:
            self.tk.bell()
            mb.showerror("Conversion Error",str(e),parent=self.tk)

    ###                       ###
    # Save/Load Plist Functions #
    ###                       ###

    def duplicate_plist(self, event = None):
        windows = self.stackorder(self.tk)
        if not len(windows):
            # Nothing to do
            return
        window = windows[-1] # Get the last item (most recent)
        if window == self.tk:
            return
        plist_data = window.nodes_to_values()
        plistwindow.PlistWindow(self, self.tk).open_plist(None,plist_data)

    def save_plist(self, event = None):
        windows = self.stackorder(self.tk)
        if not len(windows):
            # Nothing to do
            return
        window = windows[-1] # Get the last item (most recent)
        if window == self.tk:
            return
        window.save_plist(event)
    
    def save_plist_as(self, event = None):
        windows = self.stackorder(self.tk)
        if not len(windows):
            # Nothing to do
            return
        window = windows[-1] # Get the last item (most recent)
        if window == self.tk:
            return
        window.save_plist_as(event)

    def undo(self, event = None):
        windows = self.stackorder(self.tk)
        if not len(windows):
            # Nothing to do
            return
        window = windows[-1] # Get the last item (most recent)
        if window == self.tk:
            return
        window.reundo(event)

    def redo(self, event = None):
        windows = self.stackorder(self.tk)
        if not len(windows):
            # Nothing to do
            return
        window = windows[-1] # Get the last item (most recent)
        if window == self.tk:
            return
        window.reundo(event,False)
    
    def new_plist(self, event = None):
        # Creates a new plistwindow object
        window = plistwindow.PlistWindow(self, self.tk)
        window.focus_force()
        window.update()
        return window

    def open_plist(self, event=None):
        # Prompt the user to open a plist, attempt to load it, and if successful,
        # set its path as our current_plist value
        current_window = None
        windows = self.stackorder(self.tk)
        if len(windows) == 1 and windows[0] == self.start_window and windows[0].edited == False and windows[0].current_plist == None:
            # Fresh window - replace the contents
            current_window = windows[0]
        path = fd.askopenfilename(title = "Select config.plist",filetypes=[("Plist files", "*.plist")],parent=current_window)
        if not len(path):
            # User cancelled - bail
            return None
        # Verify that no other window has that file selected already
        for window in windows:
            if window == self.tk:
                continue
            if window.current_plist == path:
                # found one - just make this focus instead
                window.focus_force()
                window.update()
                window.bell()
                mb.showerror("File Already Open", "{} is already open here.".format(path), parent=window)
                return
        self.open_plist_with_path(event,path,current_window)

    def open_plist_with_path(self, event = None, path = None, current_window = None):
        if path == None:
            # Uh... wut?
            return
        path = os.path.realpath(os.path.expanduser(path))
        # Let's try to load the plist
        try:
            with open(path,"rb") as f:
                plist_data = plist.load(f,dict_type=dict if self.sort_dict else OrderedDict)
        except Exception as e:
            # Had an issue, throw up a display box
            # print("{}\a".format(str(e)))
            self.tk.bell()
            mb.showerror("An Error Occurred While Opening {}".format(os.path.basename(path)), str(e),parent=current_window)
            return None
        else:
            # Opened it correctly - let's load it, and set our values
            if current_window:
                current_window.open_plist(path,plist_data)
            else:
                # Need to create one first
                plistwindow.PlistWindow(self, self.tk).open_plist(path,plist_data)
            return True

    def stackorder(self, root):
        """return a list of root and toplevel windows in stacking order (topmost is last)"""
        c = root.children
        s = root.tk.eval('wm stackorder {}'.format(root))
        L = [x.lstrip('.') for x in s.split()]
        return [(c[x] if x else root) for x in L]

    def quit(self, event=None):
        # Check if we need to save first, then quit if we didn't cancel
        for window in self.stackorder(self.tk)[::-1]:
            if window == self.tk:
                continue
            if window.check_save() == None:
                # User cancelled or we failed to save, bail
                return
            window.destroy()
        # Actually quit the tkinter session
        self.tk.destroy()

if __name__ == '__main__':
    plists = []
    if len(sys.argv) > 1:
        plists = sys.argv[1:]
    p = ProperTree(plists)
