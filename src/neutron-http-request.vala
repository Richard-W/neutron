/*
 * This file is part of the neutron project.
 * 
 * Copyright 2013 Richard Wiedenhöft <richard.wiedenhoeft@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * Contains all values, the parser extracted from the request
 */
public abstract class Neutron.Http.Request : Object {
	/**
	 * Should be constructed by the library
	 */
	protected Request() {
	}

	/**
	 * The requested path 
	 */
	public abstract string path {
		get;
	}

	/**
	 * Http-Method (e.g. GET, POST, PROPFIND)
	 */
	public abstract string method {
		get;
	}

	/**
	 * Whether an encrypted connection is used
	 */
	public abstract bool uses_tls {
		get;
	}

	/**
	 * The unique session-object
	 */
	public abstract Session? session {
		get;
	}

	/**
	 * Get string from POST-body 
	 */
	public abstract string? get_post_var(string key);

	/**
	 * Get string from Request (e.g. /index.html?foo=bar) 
	 */
	public abstract string? get_request_var(string key);

	/**
	 * Get string from Cookie 
	 */
	public abstract string? get_cookie_var(string key);

	/**
	 * Get string from header 
	 */
	public abstract string? get_header_var(string key);

	/**
	 * Return all set keys 
	 */
	public abstract string[]? get_post_vars();

	/**
	 * Return all set keys 
	 */
	public abstract string[]? get_request_vars();

	/**
	 * Return all set keys 
	 */
	public abstract string[]? get_cookie_vars();

	/**
	 * Return all set keys 
	 */
	public abstract string[]? get_header_vars();
}

