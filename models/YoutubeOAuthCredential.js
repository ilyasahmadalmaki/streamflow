const { db } = require('../db/database');
const { v4: uuidv4 } = require('uuid');

class YoutubeOAuthCredential {
  static findAll(userId) {
    return new Promise((resolve, reject) => {
      db.all(
        `SELECT
          c.*,
          (
            SELECT COUNT(*)
            FROM youtube_channels ch
            WHERE ch.oauth_credential_id = c.id
          ) AS channel_count
         FROM youtube_oauth_credentials c
         WHERE c.user_id = ?
         ORDER BY c.created_at ASC`,
        [userId],
        (err, rows) => {
          if (err) return reject(err);
          resolve(rows || []);
        }
      );
    });
  }

  static findById(id) {
    return new Promise((resolve, reject) => {
      db.get(
        `SELECT * FROM youtube_oauth_credentials WHERE id = ?`,
        [id],
        (err, row) => {
          if (err) return reject(err);
          resolve(row);
        }
      );
    });
  }

  static findByIdAndUser(id, userId) {
    return new Promise((resolve, reject) => {
      db.get(
        `SELECT * FROM youtube_oauth_credentials
         WHERE id = ? AND user_id = ?`,
        [id, userId],
        (err, row) => {
          if (err) return reject(err);
          resolve(row);
        }
      );
    });
  }

  static async create(data) {
    const id = uuidv4();

    return new Promise((resolve, reject) => {
      db.run(
        `INSERT INTO youtube_oauth_credentials
         (id, user_id, name, client_id, client_secret)
         VALUES (?, ?, ?, ?, ?)`,
        [
          id,
          data.user_id,
          data.name,
          data.client_id,
          data.client_secret
        ],
        function (err) {
          if (err) return reject(err);

          resolve({
            id,
            user_id: data.user_id,
            name: data.name,
            client_id: data.client_id,
            client_secret: data.client_secret
          });
        }
      );
    });
  }

  static update(id, userId, data) {
    const fields = [];
    const values = [];

    if (data.name !== undefined) {
      fields.push('name = ?');
      values.push(data.name);
    }

    if (data.client_id !== undefined) {
      fields.push('client_id = ?');
      values.push(data.client_id);
    }

    if (data.client_secret !== undefined) {
      fields.push('client_secret = ?');
      values.push(data.client_secret);
    }

    if (fields.length === 0) {
      return Promise.resolve(null);
    }

    fields.push('updated_at = CURRENT_TIMESTAMP');
    values.push(id, userId);

    return new Promise((resolve, reject) => {
      db.run(
        `UPDATE youtube_oauth_credentials
         SET ${fields.join(', ')}
         WHERE id = ? AND user_id = ?`,
        values,
        function (err) {
          if (err) return reject(err);

          if (this.changes === 0) {
            return resolve(null);
          }

          resolve({
            id,
            user_id: userId,
            ...data
          });
        }
      );
    });
  }

  static delete(id, userId) {
    return new Promise((resolve, reject) => {
      db.get(
        `SELECT COUNT(*) AS count
         FROM youtube_channels
         WHERE oauth_credential_id = ?`,
        [id],
        (err, row) => {
          if (err) return reject(err);

          if (row && row.count > 0) {
            return resolve({
              deleted: false,
              inUse: true,
              channelCount: row.count
            });
          }

          db.run(
            `DELETE FROM youtube_oauth_credentials
             WHERE id = ? AND user_id = ?`,
            [id, userId],
            function (deleteErr) {
              if (deleteErr) return reject(deleteErr);

              resolve({
                deleted: this.changes > 0,
                inUse: false,
                channelCount: 0
              });
            }
          );
        }
      );
    });
  }

  static count(userId) {
    return new Promise((resolve, reject) => {
      db.get(
        `SELECT COUNT(*) AS count
         FROM youtube_oauth_credentials
         WHERE user_id = ?`,
        [userId],
        (err, row) => {
          if (err) return reject(err);
          resolve(row ? row.count : 0);
        }
      );
    });
  }
}

module.exports = YoutubeOAuthCredential;
