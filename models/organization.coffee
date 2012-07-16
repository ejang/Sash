mongoose = require 'mongoose'
timestamps = require 'mongoose-timestamps'
Promise = require('mongoose').Promise
Schema = mongoose.Schema
db = mongoose.createConnection "mongodb://localhost:27017/badges-#{process.env.NODE_ENV}"

crypto = require 'crypto'

hexDigest = (string)->
  sha = crypto.createHash('sha256');
  sha.update('awesome')
  sha.digest('hex')


OrganizationSchema = new Schema {
    name: String
    origin: String
    org: String
    api_key: String
    contact: String
    hashed_password: String
  },
  strict: true

OrganizationSchema.plugin(timestamps)

OrganizationSchema.virtual('password')

OrganizationSchema.pre 'save', (next)->
  if @password
    @hashed_password = hexDigest(@password)
    @setValue('password', null)
  next()

OrganizationSchema.methods.assertion = ->
  assertion = {}
  assertion.name = @name
  assertion.origin = @origin if @origin?
  assertion.contact = @contact if @contact?
  assertion.org = @org if @org?
  return assertion
  

OrganizationSchema.methods.users = (callback)->
  promise = new Promise
  promise.addBack(callback) if callback
  @model('User').find organization: @id,
    promise.resolve.bind(promise)
  promise

OrganizationSchema.methods.badges = (limit, callback)->
  promise = new Promise

  if callback
    promise.addBack callback
  query = @model('Badge').where('issuer_id', @id)
  if limit
    query = query.limit(limit)
  query.exec (err, result)->
    promise.resolve(err, result)

  promise

OrganizationSchema.methods.badgeCount = (callback)->
  promise = new Promise

  if callback
    promise.addBack callback
  query = @model('Badge').count('issuer_id', @id)
  query.exec (err, result)->
    promise.resolve(err, result)

  promise



Organization = db.model 'Organization', OrganizationSchema

module.exports = Organization
