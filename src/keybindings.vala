/* 
Copyright (c) 2011 by Simon Schneegans

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <http://www.gnu.org/licenses/>. 
*/

namespace GnomePie {

    public class KeybindingManager : GLib.Object {

        private Gee.List<Keybinding> _bindings = new Gee.ArrayList<Keybinding>();
     
        // Locked modifiers used to grab all keys whatever lock key is pressed.
        private static uint[] lock_modifiers = {
            0,
            Gdk.ModifierType.MOD2_MASK, // NUM_LOCK
            Gdk.ModifierType.LOCK_MASK, // CAPS_LOCK
            Gdk.ModifierType.MOD5_MASK, // SCROLL_LOCK
            Gdk.ModifierType.MOD2_MASK|Gdk.ModifierType.LOCK_MASK,
            Gdk.ModifierType.MOD2_MASK|Gdk.ModifierType.MOD5_MASK,
            Gdk.ModifierType.LOCK_MASK|Gdk.ModifierType.MOD5_MASK,
            Gdk.ModifierType.MOD2_MASK|Gdk.ModifierType.LOCK_MASK|Gdk.ModifierType.MOD5_MASK
        };
     
        // Helper class to store keybinding
        private class Keybinding {
        
            public Keybinding(string accelerator, int keycode, Gdk.ModifierType modifiers, KeybindingHandlerFunc handler) {
                this.accelerator = accelerator;
                this.keycode = keycode;
                this.modifiers = modifiers;
                this.handler = handler;
            }
     
            public string accelerator { get; set; }
            public int keycode { get; set; }
            public Gdk.ModifierType modifiers { get; set; }
            public KeybindingHandlerFunc handler { get; set; }
        }
     
        // Keybinding func needed to bind key to handler
        public delegate void KeybindingHandlerFunc(Gdk.Event event);
     
        public KeybindingManager() {
            // init filter to retrieve X.Events
            Gdk.Window rootwin = Gdk.get_default_root_window();
            if(rootwin != null) {
                rootwin.add_filter(event_filter);
            }
        }
     
        // Bind accelerator to given handler
        public void bind(string accelerator, KeybindingHandlerFunc handler) {
     
            // convert accelerator
            uint keysym;
            Gdk.ModifierType modifiers;
            Gtk.accelerator_parse(accelerator, out keysym, out modifiers);
     
            Gdk.Window rootwin = Gdk.get_default_root_window();     
            X.Display display = Gdk.x11_drawable_get_xdisplay(rootwin);
            X.ID xid = Gdk.x11_drawable_get_xid(rootwin);
            int keycode = display.keysym_to_keycode(keysym);            
     
            if(keycode != 0) {
                // trap XErrors to avoid closing of application
                // even when grabing of key fails
                Gdk.error_trap_push();
     
                // grab key finally
                // also grab all keys which are combined with a lock key such NumLock
                foreach(uint lock_modifier in lock_modifiers) {     
                    display.grab_key(keycode, modifiers|lock_modifier, xid, false, X.GrabMode.Async, X.GrabMode.Async);
                }
     
                // wait until all X request have been processed
                Gdk.flush();
     
                // store binding
                Keybinding binding = new Keybinding(accelerator, keycode, modifiers, handler);
                _bindings.add(binding);
     
                debug("Successfully bound key " + accelerator);
            }
        }
     
        // Unbind given accelerator.
        public void unbind(string accelerator) {
            debug("Unbinding key " + accelerator);
     
            Gdk.Window rootwin = Gdk.get_default_root_window();     
            X.Display display = Gdk.x11_drawable_get_xdisplay(rootwin);
            X.ID xid = Gdk.x11_drawable_get_xid(rootwin);
     
            // unbind all keys with given accelerator
            Gee.List<Keybinding> remove_bindings = new Gee.ArrayList<Keybinding>();
            foreach(Keybinding binding in _bindings) {
                if(str_equal(accelerator, binding.accelerator)) {
                    foreach(uint lock_modifier in lock_modifiers) {
                        display.ungrab_key(binding.keycode, binding.modifiers, xid);
                    }
                    remove_bindings.add(binding);                    
                }
            }
     
            // remove unbinded keys
            _bindings.remove_all(remove_bindings);
        }
     
        // Event filter method needed to fetch X.Events
        public Gdk.FilterReturn event_filter(Gdk.XEvent gdk_xevent, Gdk.Event gdk_event) {
            Gdk.FilterReturn filter_return = Gdk.FilterReturn.CONTINUE;
     
            void* pointer = &gdk_xevent;
            X.Event* xevent = (X.Event*) pointer;
     
             if(xevent->type == X.EventType.KeyPress) {
                foreach(Keybinding binding in _bindings) {
                    // remove NumLock, CapsLock and ScrollLock from key state
                    uint event_mods = xevent.xkey.state & ~ (lock_modifiers[7]);
                    if(xevent->xkey.keycode == binding.keycode && event_mods == binding.modifiers) {
                        // call all handlers with pressed key and modifiers
                        binding.handler(gdk_event);
                    }
                }
             }
     
            return filter_return;
        }
    }

}
