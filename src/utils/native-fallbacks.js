// Native module fallback handler for obfuscated builds
// This file helps handle native modules that may not be available in packaged environments

const fs = require('fs');
const path = require('path');

class NativeModuleHandler {
  static createFallbacks() {
    const fallbacks = {
      sqlite3: this.createSqlite3Fallback(),
      keytar: this.createKeytarFallback(),
      bcrypt: this.createBcryptFallback()
    };

    return fallbacks;
  }

  static createSqlite3Fallback() {
    try {
      // Try to load the native sqlite3 module
      return require('sqlite3');
    } catch (error) {
      console.warn('sqlite3 native module not available, using memory fallback');
      
      // Return a minimal fallback that uses memory database
      return {
        Database: class MockDatabase {
          constructor(filename, callback) {
            this.filename = filename;
            this.isMemory = filename === ':memory:';
            if (callback) callback(null);
          }

          serialize(fn) {
            if (fn) fn();
          }

          run(sql, params, callback) {
            console.warn('SQLite operation attempted in fallback mode:', sql);
            if (callback) callback(null);
          }

          get(sql, params, callback) {
            console.warn('SQLite query attempted in fallback mode:', sql);
            if (callback) callback(null, null);
          }

          all(sql, params, callback) {
            console.warn('SQLite query attempted in fallback mode:', sql);
            if (callback) callback(null, []);
          }

          close(callback) {
            if (callback) callback(null);
          }
        },
        OPEN_READWRITE: 2,
        OPEN_CREATE: 4
      };
    }
  }

  static createKeytarFallback() {
    try {
      return require('keytar');
    } catch (error) {
      console.warn('keytar native module not available, using memory fallback');
      
      // In-memory credential storage for fallback
      const memoryStore = new Map();
      
      return {
        async getPassword(service, account) {
          const key = `${service}:${account}`;
          return memoryStore.get(key) || null;
        },

        async setPassword(service, account, password) {
          const key = `${service}:${account}`;
          memoryStore.set(key, password);
        },

        async deletePassword(service, account) {
          const key = `${service}:${account}`;
          return memoryStore.delete(key);
        },

        async findCredentials(service) {
          const credentials = [];
          for (const [key, password] of memoryStore.entries()) {
            if (key.startsWith(`${service}:`)) {
              const account = key.substring(service.length + 1);
              credentials.push({ account, password });
            }
          }
          return credentials;
        }
      };
    }
  }

  static createBcryptFallback() {
    try {
      return require('bcrypt');
    } catch (error) {
      console.warn('bcrypt native module not available, using bcryptjs fallback');
      
      try {
        // Use bcryptjs as fallback
        const bcryptjs = require('bcryptjs');
        return {
          hash: bcryptjs.hash,
          hashSync: bcryptjs.hashSync,
          compare: bcryptjs.compare,
          compareSync: bcryptjs.compareSync,
          genSalt: bcryptjs.genSalt,
          genSaltSync: bcryptjs.genSaltSync
        };
      } catch (bcryptjsError) {
        console.error('Neither bcrypt nor bcryptjs are available');
        
        // Minimal fallback that doesn't actually hash (NOT FOR PRODUCTION)
        return {
          hash: async (data, rounds) => data,
          hashSync: (data, rounds) => data,
          compare: async (data, hash) => data === hash,
          compareSync: (data, hash) => data === hash,
          genSalt: async (rounds) => 'fallback-salt',
          genSaltSync: (rounds) => 'fallback-salt'
        };
      }
    }
  }

  static setupGlobalFallbacks() {
    // Setup global fallbacks for require calls
    const Module = require('module');
    const originalRequire = Module.prototype.require;

    Module.prototype.require = function(id) {
      try {
        return originalRequire.apply(this, arguments);
      } catch (error) {
        if (id === 'sqlite3') {
          return NativeModuleHandler.createSqlite3Fallback();
        } else if (id === 'keytar') {
          return NativeModuleHandler.createKeytarFallback();
        } else if (id === 'bcrypt') {
          return NativeModuleHandler.createBcryptFallback();
        }
        throw error;
      }
    };
  }
}

module.exports = NativeModuleHandler;